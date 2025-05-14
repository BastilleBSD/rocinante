#!/bin/sh
#
# Copyright (c) 2021-2022, Christer Edwards <christer.edwards@gmail.com>
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

bootstrap_usage() {
    error_exit "Usage: rocinante bootstrap [option(s)] URL"
}

# Handle options.
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            cmd_usage
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*)
            error_exit "[ERROR]: Unknown option: \"${1}\""
            ;;
        *)
            break
            ;;

    esac
done

if [ "$#" -eq 0 ]; then
    bootstrap_usage
fi

fetch_template() {

    # Ensure required directories are in place

    ## ${rocinate_prefix}
    if [ ! -d "${rocinante_prefix}" ]; then
        if [ "${rocinante_zfs_enable}" = "YES" ]; then
            if [ -n "${rocinante_zfs_zpool}" ]; then
                zfs create ${rocinante_zfs_options} -o mountpoint="${rocinante_prefix}" "${rocinante_zfs_zpool}/rocinante"
            fi
        else
            mkdir -p "${rocinante_prefix}"
        fi
    # Make sure the dataset is mounted in the proper place
    elif [ -d "${rocinante_prefix}" ]; then
        if ! zfs list "${rocinante_zfs_zpool}/rocinante" >/dev/null; then
            zfs create ${rocinante_zfs_options} -o mountpoint="${rocinante_prefix}" "${rocinante_zfs_zpool}/rocinante"
        elif [ "$(zfs get -H -o value mountpoint ${rocinante_zfs_zpool}/rocinante)" != "${rocinante_prefix}" ]; then
            zfs set mountpoint="${rocinante_prefix}" "${rocinante_zfs_zpool}/rocinante"
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
    _raw_template_dir=${rocinante_templatesdir}/${_user}/${_repo}

    ## support for non-git
    if ! which -s git; then
        error_notify "[ERROR]: Git not found."
        error_exit "Not yet implemented."
    else
        if [ ! -d "${rocinante_templatesdir}/.git" ]; then
            if ! git clone "${_url}" "${_raw_template_dir}"; then
                error_notify "Clone unsuccessful."
            fi
        elif [ -d "${rocinante_templatesdir}/.git" ]; then
            if ! git -C "${_raw_template_dir}" pull; then
                error_notify "Template update unsuccessful."
            fi
        fi
    fi

    # Extract templates in project/template format
    if [ ! -f ${_raw_template_dir}/Bastillefile ]; then
        # Extract template in project/template format
        find "${_raw_template_dir}" -type f -name Bastillefile | while read -r _file; do
            _template_dir="$(dirname ${_file})"
            _project_dir="$(dirname ${_template_dir})"
            _template_name="$(basename ${_template_dir})"
            _project_name="$(basename ${_project_dir})"
            _complete_template="${_project_name}/${_template_name}"
            cp -fR "${_project_dir}" "${rocinante_templatesdir}"
            rocinante verify "${_complete_template}"
        done
        
        # Remove the cloned repo
        if [ -n "${_user}" ]; then
            rm -r "${rocinante_templatesdir:?}/${_user:?}"
        fi
        
    else
        # Verify a single template
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
    git@*:*/*)
        ROCINANTE_TEMPLATE_URL=${1}
        git_repository=$(echo "${1}" | awk -F : '{ print $2 }')
        ROCINANTE_TEMPLATE_USER=$(echo "${git_repository}" | awk -F / '{ print $1 }')
        ROCINANTE_TEMPLATE_REPO=$(echo "${git_repository}" | awk -F / '{ print $2 }')
        fetch_template
        ;;
esac