#!/bin/sh
#
# Copyright (c) 2021, Christer Edwards <christer.edwards@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

. /usr/local/libexec/rocinante/common.sh
. /usr/local/etc/rocinante.conf

fetch_usage() {
    error_exit "Usage: rocinante bootstrap URL"
}

# Handle special-case commands first.
case "$1" in
help|-h|--help)
    fetch_usage
    ;;
esac

if [ $# -eq 0 ]; then
    fetch_usage
fi

fetch_template() {
    ## ${rocinate_prefix}
    if [ ! -d "${rocinante_prefix}" ]; then
        if [ "${rocinante_zfs_enable}" = "YES" ]; then
            if [ -n "${rocinante_zfs_zpool}" ]; then
                zfs create ${rocinante_zfs_options} -o mountpoint="${rocinante_prefix}" "${rocinante_zfs_zpool}/rocinante"
            fi
        else
            mkdir -p "${rocinante_prefix}"
        fi
    fi

    ## ${rocinante_templatesdir}
    if [ ! -d "${rocinante_templatesdir}" ]; then
        if [ "${rocinante_zfs_enable}" = "YES" ]; then
            if [ -n "${rocinante_zfs_zpool}" ]; then
                zfs create ${rocinante_zfs_options} -o mountpoint="${rocinante_templatesdir}" "${rocinante_zfs_zpool}/rocinante/templates"
            fi
        else
            mkdir -p "${rocinante_templatesdir}"
        fi
    fi

    ## define basic variables
    _url=${ROCINANTE_TEMPLATE_URL}
    _user=${ROCINANTE_TEMPLATE_USER}
    _repo=${ROCINANTE_TEMPLATE_REPO}
    _template=${rocinante_templatesdir}/${_user}/${_repo}
    _template_user=${rocinante_templatesdir}/${_user}

    ## support for non-git
    if ! which -s git; then
        if echo ${_url} | grep 'gitlab.com' 1>/dev/null; then
            mkdir -p ${_template_user}
            for _branch in ${rocinante_branches}; do
                fetch -q "${_url}/-/archive/${_branch}/${_repo}-${_branch}.tar.gz" -o ${_template_user}/${_repo}.tar.gz 2>/dev/null
                tar -C ${_template_user} -xf "${_template_user}/${_repo}.tar.gz" 2>/dev/null
                mv ${_template_user}/${_repo}-${_branch} ${_template_user}/${_repo} 2>/dev/null
            done
            rocinante verify "${_user}/${_repo}"
        elif echo "${_url}" | grep 'github' 1>/dev/null; then
            mkdir -p "${_template_user}"
            for _branch in ${rocinante_branches}; do
                fetch -q "${_url}/archive/refs/heads/${_branch}.tar.gz" -o ${_template_user}/${_repo}.tar.gz 2>/dev/null
                tar -C ${_template_user} -xf "${_template_user}/${_repo}.tar.gz" 2>/dev/null
                mv ${_template_user}/${_repo}-${_branch} ${_template_user}/${_repo} 2>/dev/null
            done
            rocinante verify "${_user}/${_repo}"
        fi
    else
        if [ ! -d "${_template}/.git" ]; then
            git clone "${_url}" "${_template}" || error_notify "Clone unsuccessful."
        elif [ -d "${_template}/.git" ]; then
            git -C "${_template}" pull ||\
            error_notify "Template update unsuccessful."
        fi
        rocinante verify "${_user}/${_repo}"
    fi
}

case "${1}" in
http?://*/*/*)
    ROCINANTE_TEMPLATE_URL=${1}
    ROCINANTE_TEMPLATE_USER=$(echo "${1}" | awk -F / '{ print $4 }')
    ROCINANTE_TEMPLATE_REPO=$(echo "${1}" | awk -F / '{ print $5 }')
    fetch_template
    ;;
esac
