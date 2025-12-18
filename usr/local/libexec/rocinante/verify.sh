#!/bin/sh
#
# Copyright (c) 2021-2025, Christer Edwards <christer.edwards@gmail.com>
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

usage() {
    error_exit "Usage: rocinante verify [option(s)] TEMPLATE"
}

handle_template_include() {
    case ${TEMPLATE_INCLUDE} in
        http?://*/*/*)
            rocinante bootstrap "${TEMPLATE_INCLUDE}"
            ;;
        */*)
            ROCINANTE_TEMPLATE_USER=$(echo "${TEMPLATE_INCLUDE}" | awk -F / '{ print $1 }')
            ROCINANTE_TEMPLATE_REPO=$(echo "${TEMPLATE_INCLUDE}" | awk -F / '{ print $2 }')
            rocinante verify "${ROCINANTE_TEMPLATE_USER}/${ROCINANTE_TEMPLATE_REPO}"
            ;;
        *)
            error_exit "Template INCLUDE content not recognized."
            ;;
    esac
}

verify_template() {

    template_path=${rocinante_templatesdir}/${ROCINANTE_TEMPLATE}
    hook_validate=0

    for hook in TARGET INCLUDE PRE OVERLAY FSTAB PF PKG SYSRC SERVICE CMD Bastillefile; do
        path=${template_path}/${hook}
        if [ -s "${path}" ]; then
            hook_validate=$((hook_validate+1))
            info "\nDetected ${hook} hook."

            ## line count must match newline count
            if [ $(wc -l "${path}" | awk '{print $1}') -ne $(grep -c $'\n' "${path}") ]; then
                info "\n[${hook}]:"
                error_notify "[ERROR]: ${ROCINANTE_TEMPLATE}:${hook} [failed]."
                error_notify "Line numbers don't match line breaks."
                error_exit "Template validation failed."
            ## if INCLUDE; recursive verify
            elif [ "${hook}" = 'INCLUDE' ]; then
                info "\n[${hook}]:"
                cat "${path}"
                while read include; do
                    info "[${hook}]:[${include}]:"
                    TEMPLATE_INCLUDE="${include}"
                    handle_template_include
                done < "${path}"

            ## if tree; tree -a rocinante_template/_dir
            elif [ "${hook}" = 'OVERLAY' ]; then
                info "\n[${hook}]:"
                cat "${path}"
                while read dir; do
                    info "[${hook}]:[${dir}]:"
                        if [ -x "/usr/local/bin/tree" ]; then
                            /usr/local/bin/tree -a "${template_path}/${dir}"
                        else
                           find "${template_path}/${dir}" -print | sed -e 's;[^/]*/;|___;g;s;___|; |;g'
                        fi
                done < "${path}"
            elif [ "${hook}" = 'Bastillefile' ]; then
                info "\n[${hook}]:"
                cat "${path}"
                while read line; do
                    cmd=$(echo "${line}" | awk '{print tolower($1);}')
                    ## if include; recursive verify
                    if [ "${cmd}" = 'include' ]; then
                        TEMPLATE_INCLUDE=$(echo "${line}" | awk '{print $2;}')
                        handle_template_include
                    fi
                done < "${path}"
            else
                info "\n[${hook}]:"
                cat "${path}"
            fi
        fi
    done

    ## remove bad templates
    if [ "${hook_validate}" -lt 1 ]; then
        rm -rf "${template_path}"
        error_notify "[ERROR]: No valid template hooks found."
        error_exit "Template discarded: ${ROCINANTE_TEMPLATE}"
    fi

    ## if validated; ready to use
    if [ "${_hook_validate}" -gt 0 ]; then
        info "\nTemplate ready to use.\n"
    fi
}

# Handle options.
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            usage
            ;;
        -x|--debug)
            enable_debug
            shift
            ;;
        -*) 
            error_exit "[ERROR]: Unknown Option: \"${1}\""
            ;;
        *)
            break
            ;;
    esac
done

if [ "$#" -ne 1 ]; then
    usage
fi

case "${1}" in
    http?*)
        usage
        ;;
    */*)
        ROCINANTE_TEMPLATE=$1
        verify_template
        ;;
    *)
        usage
        ;;
esac
