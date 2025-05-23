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

template_usage() {
    error_exit "Usage: rocinante template [option(s)] [--convert] PROJECT/TEMPLATE"
}

post_command_hook() {

    _jail=$1
    _cmd=$2
    _args=$3

    case $_cmd in
        rdr)
            echo -e ${_args}
    esac
}

get_arg_name() {
    echo "${1}" | sed -E 's/=.*//'
}

parse_arg_value() {
    # Parses the value after = and then escapes back/forward slashes and single quotes in it. -- cwells
    # Enclose ARG value inside ""
    echo "${1}" | \
    sed -E 's/[^=]+=?//' | \
    sed -e 's/\\/\\\\/g' \
    -e 's/\//\\\//g' \
    -e 's/'\''/'\''\\'\'\''/g' \
    -e 's/&/\\&/g' \
    -e 's/"//g'
}

get_arg_value() {

    _name_value_pair="${1}"
    shift
    _arg_name="$(get_arg_name "${_name_value_pair}")"

    # Remaining arguments in $@ are the script arguments, which take precedence. -- cwells
    for _script_arg in "$@"; do
        case ${_script_arg} in
            --arg)
                # Parse whatever is next. -- cwells
                _next_arg='true' ;;
            *)
                if [ "${_next_arg}" = 'true' ]; then # This is the parameter after --arg. -- cwells
                    _next_arg=''
                    if [ "$(get_arg_name "${_script_arg}")" = "${_arg_name}" ]; then
                        parse_arg_value "${_script_arg}"
                        return
                    fi
                fi
                ;;
        esac
    done

    # Check the ARG_FILE if one was provided. --cwells
    if [ -n "${ARG_FILE}" ]; then
        # To prevent a false empty value, only parse the value if this argument exists in the file. -- cwells
        if grep "^${_arg_name}=" "${ARG_FILE}" > /dev/null 2>&1; then
            parse_arg_value "$(grep "^${_arg_name}=" "${ARG_FILE}")"
            return
        fi
    fi

    # Return the default value, which may be empty, from the name=value pair. -- cwells
    parse_arg_value "${_name_value_pair}"
}

render() {
    _file_path="${1}/${2}"
    if [ -d "${_file_path}" ]; then # Recursively render every file in this directory. -- cwells
        echo "Rendering Directory: ${_file_path}"
        find "${_file_path}" \( -type d -name .git -prune \) -o -type f
        find "${_file_path}" \( -type d -name .git -prune \) -o -type f -print0 | $(eval "xargs -0 sed -i '' ${ARG_REPLACEMENTS}")
    elif [ -f "${_file_path}" ]; then
        echo "Rendering File: ${_file_path}"
        eval "sed -i '' ${ARG_REPLACEMENTS} '${_file_path}'"
    else
        warn "[WARNING]: Path not found for render: ${2}"
    fi
}

line_in_file() {

    _filepath="$(echo ${1} | awk '{print $1}')"
    _line="$(echo ${2} | awk '{print $1}')"
    if [ -f "${_jailpath}/${_filepath}" ]; then
        if ! grep -qxF "${_line}" "${_jailpath}/${_filepath}"; then
            echo "${_line}" >> "${_jailpath}/${_filepath}"
	fi
    else
        warn "[WARNING]: Path not found for line_in_file: ${_filepath}"
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

if [ "$#" -lt 1 ]; then
    template_usage
fi

TEMPLATE="${1}"
rocinante_template=${rocinante_templatesdir}/${TEMPLATE}
if [ -z "${HOOKS}" ]; then
    HOOKS='LIMITS INCLUDE PRE FSTAB PF PKG OVERLAY CONFIG SYSRC SERVICE CMD RENDER'
fi

# Special case conversion of hook-style template files into a Bastillefile. -- cwells
if [ "${TARGET}" = '--convert' ]; then
    if [ -d "${TEMPLATE}" ]; then # A relative path was provided. -- cwells
        cd "${TEMPLATE}" || error_exit "[ERROR]: Failed to change to directory: ${TEMPLATE}"
    elif [ -d "${rocinante_template}" ]; then
        cd "${bastille_template}" || error_exit "[ERROR]: Failed to change to directory: ${TEMPLATE}"
    else
        error_exit "Template not found: ${TEMPLATE}"
    fi

    echo "Converting template: ${TEMPLATE}"

    HOOKS="ARG ${HOOKS}"
    for _hook in ${HOOKS}; do
        if [ -s "${_hook}" ]; then
            # Default command is the hook name and default args are the line from the file. -- cwells
            _cmd="${_hook}"
            _args_template='${_line}'

            # Replace old hook names with Bastille command names. -- cwells
            case ${_hook} in
                CONFIG|OVERLAY)
                    _cmd='CP'
                    _args_template='${_line} /'
                    ;;
                FSTAB)
                    _cmd='MOUNT' ;;
                PF)
                    _cmd='RDR' ;;
                PRE)
                    _cmd='CMD' ;;
            esac

            while read _line; do
                if [ -z "${_line}" ]; then
                    continue
                fi
                eval "_args=\"${_args_template}\""
                echo "${_cmd} ${_args}" >> Bastillefile
            done < "${_hook}"
            echo '' >> Bastillefile
            rm "${_hook}"
        fi
    done

    info "\nTemplate converted: ${TEMPLATE}"
    exit 0
fi

case ${TEMPLATE} in
    http?://*/*/*)
        TEMPLATE_DIR=$(echo "${TEMPLATE}" | awk -F / '{ print $4 "/" $5 }')
        if [ ! -d "${rocinante_templatesdir}/${TEMPLATE_DIR}" ]; then
            info "\nBootstrapping ${TEMPLATE}..."
            if ! rocinante bootstrap "${TEMPLATE}"; then
                error_exit "[ERROR]: Failed to bootstrap template: ${TEMPLATE}"
            fi
        fi
        TEMPLATE="${TEMPLATE_DIR}"
        rocinante_template=${rocinante_templatesdir}/${TEMPLATE}
        ;;
    */*)
        if [ ! -d "${rocinante_templatesdir}/${TEMPLATE}" ]; then
            if [ ! -d ${TEMPLATE} ]; then
                error_exit "[ERROR]: ${TEMPLATE} not found."
            else
                rocinante_template=${TEMPLATE}
            fi
        fi
        ;;
    *)
        error_exit "Template name/URL not recognized."
esac

# Check for an --arg-file parameter. -- cwells
for _script_arg in "$@"; do
    case ${_script_arg} in
        --arg-file)
            # Parse whatever is next. -- cwells
            _next_arg='true' ;;
        *)
            if [ "${_next_arg}" = 'true' ]; then # This is the parameter after --arg-file. -- cwells
                _next_arg=''
                ARG_FILE="${_script_arg}"
                break
            fi
            ;;
    esac
done

if [ -n "${ARG_FILE}" ] && [ ! -f "${ARG_FILE}" ]; then
    error_exit "[ERROR]: File not found: ${ARG_FILE}"
fi

info "\n[TEMPLATE]:"
echo "Applying template: ${TEMPLATE}..."

# Build a list of sed commands like this: -e 's/${username}/root/g' -e 's/${domain}/example.com/g'
# Values provided by default (without being defined by the user) are listed here. -- cwells
ARG_REPLACEMENTS="-e 's/\${JAIL_IP}/${_jail_ip}/g' -e 's/\${JAIL_NAME}/${_jail}/g'"
# This is parsed outside the HOOKS loop so an ARG file can be used with a Bastillefile. -- cwells
if [ -s "${rocinante_template}/ARG" ]; then
    while read _line; do
        if [ -z "${_line}" ]; then
            continue
        fi
        _arg_name=$(get_arg_name "${_line}")
        _arg_value=$(get_arg_value "${_line}" "$@")
        if [ -z "${_arg_value}" ]; then
            warn "[WARNING]: No value provided for arg: ${_arg_name}"
        fi
        ARG_REPLACEMENTS="${ARG_REPLACEMENTS} -e 's/\${${_arg_name}}/${_arg_value}/g'"
    done < "${rocinante_template}/ARG"
fi

if [ -s "${rocinante_template}/Bastillefile" ]; then
    # Ignore blank lines and comments. -- cwells
    SCRIPT=$(awk '{ if (substr($0, length, 1) == "\\") { printf "%s", substr($0, 1, length-1); } else { print $0; } }' "${rocinante_template}/Bastillefile" | grep -v '^[[:blank:]]*$' | grep -v '^[[:blank:]]*#')
    # Use a newline as the separator. -- cwells
    IFS='
'
    set -f
    for _line in ${SCRIPT}; do
        # First word converted to lowercase is the Bastille command. -- cwells
        _cmd=$(echo "${_line}" | awk '{print tolower($1);}')
        # Rest of the line with "arg" variables replaced will be the arguments. -- cwells
        _args=$(echo "${_line}" | awk -F '[ ]' '{$1=""; sub(/^ */, ""); print;}' | eval "sed ${ARG_REPLACEMENTS}")

        # Apply overrides for commands/aliases and arguments. -- cwells
        case $_cmd in
            arg) # This is a template argument definition. -- cwells
                _arg_name=$(get_arg_name "${_args}")
                _arg_value=$(get_arg_value "${_args}" "$@")
                if [ -z "${_arg_value}" ]; then
                    warn "[WARNING]: No value provided for arg: ${_arg_name}"
                fi
                # Build a list of sed commands like this: -e 's/${username}/root/g' -e 's/${domain}/example.com/g'
                ARG_REPLACEMENTS="${ARG_REPLACEMENTS} -e 's/\${${_arg_name}}/${_arg_value}/g'"
                continue
                ;;
            cmd)
                # Escape single-quotes in the command being executed. -- cwells
                _args=$(echo "${_args}" | sed "s/'/'\\\\''/g")
                # Allow redirection within the jail. -- cwells
                _args="'${_args}'"
                ;;
            cp|copy)
                _cmd='cp'
                # Convert relative "from" path into absolute path inside the template directory. -- cwells
                if [ "${_args%${_args#?}}" != '/' ] && [ "${_args%${_args#??}}" != '"/' ]; then
                    _args="${rocinante_template}/${_args}"
                fi
                ;;
            fstab|mount)
                _cmd='mount' ;;
            include)
                _cmd='template' ;;
            overlay)
                _cmd='cp'
                _args="${rocinante_template}/${_args} /"
                ;;
            pkg)
                _args="install -y ${_args}" ;;
            render) # This is a path to one or more files needing arguments replaced by values. -- cwells
                render "${rocinante_jail_path}" "${_args}"
                continue
                ;;
            lif|lineinfile|line_in_file)
                line_in_file "${_args}"
                continue
                ;;
        esac

        if ! eval "rocinante ${_cmd} ${_args}"; then
            set +f
            unset IFS
            error_exit "Failed to execute command: ${_cmd}"
        fi

        post_command_hook "${_jail}" "${_cmd}" "${_args}"
    done
    set +f
    unset IFS
fi

for _hook in ${HOOKS}; do
    if [ -s "${rocinante_template}/${_hook}" ]; then
        # Default command is the lowercase hook name and default args are the line from the file. -- cwells
        _cmd=$(echo "${_hook}" | awk '{print tolower($1);}')
        _args_template='${_line}'

        # Override default command/args for some hooks. -- cwells
        case ${_hook} in
            CONFIG)
                warn "CONFIG deprecated; rename to OVERLAY."
                _args_template='${rocinante_template}/${_line} /'
                _cmd='cp' ;;
            FSTAB)
                _cmd='mount' ;;
            INCLUDE)
                _cmd='template' ;;
            OVERLAY)
                _args_template='${rocinante_template}/${_line} /'
                _cmd='cp' ;;
            PF)
                info "NOT YET IMPLEMENTED."
                continue ;;
            PRE)
                _cmd='cmd' ;;
            RENDER) # This is a path to one or more files needing arguments replaced by values. -- cwells
                render "${rocinante_jail_path}" "${_line}"
                continue
                ;;
        esac

        info "[${_jail}]:${_hook} -- START"
        if [ "${_hook}" = 'CMD' ] || [ "${_hook}" = 'PRE' ]; then
            rocinante cmd /bin/sh < "${rocinante_template}/${_hook}" || exit 1
        elif [ "${_hook}" = 'PKG' ]; then
            rocinante pkg install -y $(cat "${rocinante_template}/PKG") || exit 1
            rocinante pkg audit -F
        else
            while read _line; do
                if [ -z "${_line}" ]; then
                    continue
                fi
                # Replace "arg" variables in this line with the provided values. -- cwells
                _line=$(echo "${_line}" | eval "sed ${ARG_REPLACEMENTS}")
                eval "_args=\"${_args_template}\""
                rocinante "${_cmd}" "${_jail}" ${_args} || exit 1
            done < "${rocinante_template}/${_hook}"
        fi
        info "[${_jail}]:${_hook} -- END"
    fi
done

info "\nTemplate applied: ${TEMPLATE}\n"
