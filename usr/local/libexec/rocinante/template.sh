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
    error_exit "Usage: rocinante template [option(s)] [convert] PROJECT/TEMPLATE"
}

get_arg_name() {
    echo "${1}" | sed -E 's/=.*//'
}

parse_arg_value() {
    # Parses the value after = and then escapes back/forward slashes and single quotes in it. -- cwells
    # Enclose ARG value inside ""
    eval echo "${1}" | \
    sed -E 's/[^=]+=?//' | \
    sed -e 's/\\/\\\\/g' \
        -e 's/\//\\\//g' \
        -e 's/'\''/'\''\\'\'\''/g' \
        -e 's/&/\\&/g' \
        -e 's/"//g'
}

get_arg_value() {

    name_value_pair="${1}"
    shift
    arg_name="$(get_arg_name "${name_value_pair}")"

    # Remaining arguments in $@ are the script arguments, which take precedence. -- cwells
    for script_arg in "$@"; do
        case ${script_arg} in
            --arg)
                # Parse whatever is next. -- cwells
                next_arg='true' ;;
            *)
                if [ "${next_arg}" = 'true' ]; then # This is the parameter after --arg. -- cwells
                    next_arg=''
                    if [ "$(get_arg_name "${script_arg}")" = "${arg_name}" ]; then
                        parse_arg_value "${script_arg}"
                        return
                    fi
                fi
                ;;
        esac
    done

    # Check the ARG_FILE if one was provided. --cwells
    if [ -n "${ARG_FILE}" ]; then
        # To prevent a false empty value, only parse the value if this argument exists in the file. -- cwells
        if grep "^${arg_name}=" "${ARG_FILE}" > /dev/null 2>&1; then
            parse_arg_value "$(grep "^${arg_name}=" "${ARG_FILE}")"
            return
        fi
    fi

    # Return the default value, which may be empty, from the name=value pair. -- cwells
    parse_arg_value "${name_value_pair}"
}

render() {

    local file_path="${1}"

    if [ -z "${ARG_REPLACEMENTS}" ]; then
        error_exit "[ERROR]: Cannot execute RENDER hook. ARGS appears empty."
    fi

    if [ -d "${file_path}" ]; then # Recursively render every file in this directory. -- cwells
        echo "Rendering Directory: ${file_path}"
        find "${file_path}" \( -type d -name .git -prune \) -o -type f -print0 | $(eval "xargs -0 sed -i '' ${ARG_REPLACEMENTS}")
    elif [ -f "${file_path}" ]; then
        echo "Rendering File: ${file_path}"
        eval "sed -i '' ${ARG_REPLACEMENTS} '${file_path}'"
    else
        warn "[WARNING]: Path not found for render: ${file_path}"
    fi
}

line_in_file() {

    eval set -- "${1}"
    local line="${1}"
    local file_path="${2}"
    
    if [ -f "${file_path}" ]; then
        if ! grep -qxF "${line}" "${file_path}"; then
            echo "${line}" >> "${file_path}"
        fi
    else
        warn "[WARNING]: Path not found for line_in_file: ${file_path}"
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
    usage
fi

TEMPLATE="${1}"
rocinante_template=${rocinante_templatesdir}/${TEMPLATE}
if [ -z "${HOOKS}" ]; then
    HOOKS='LIMITS INCLUDE PRE FSTAB PF PKG OVERLAY CONFIG SYSRC SERVICE CMD RENDER'
fi

# Special case conversion of hook-style template files into a Bastillefile. -- cwells
if [ "${TARGET}" = 'convert' ]; then
    if [ -d "${TEMPLATE}" ]; then # A relative path was provided. -- cwells
        cd "${TEMPLATE}" || error_exit "[ERROR]: Failed to change to directory: ${TEMPLATE}"
    elif [ -d "${rocinante_template}" ]; then
        cd "${bastille_template}" || error_exit "[ERROR]: Failed to change to directory: ${TEMPLATE}"
    else
        error_exit "Template not found: ${TEMPLATE}"
    fi

    echo "Converting template: ${TEMPLATE}"

    HOOKS="ARG ${HOOKS}"
    for hook in ${HOOKS}; do
        if [ -s "${hook}" ]; then
            # Default command is the hook name and default args are the line from the file. -- cwells
            cmd="${_hook}"
            args_template='${line}'

            # Replace old hook names with Bastille command names. -- cwells
            case ${hook} in
                CONFIG|OVERLAY)
                    cmd='CP'
                    args_template='${line} /'
                    ;;
                FSTAB)
                    cmd='MOUNT' ;;
                PF)
                    cmd='RDR' ;;
                PRE)
                    cmd='CMD' ;;
            esac

            while read line; do
                if [ -z "${line}" ]; then
                    continue
                fi
                eval "args=\"${args_template}\""
                echo "${cmd} ${args}" >> Bastillefile
            done < "${hook}"
            echo '' >> Bastillefile
            rm "${hook}"
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
for script_arg in "$@"; do
    case ${script_arg} in
        --arg-file)
            # Parse whatever is next. -- cwells
            next_arg='true' ;;
        *)
            if [ "${next_arg}" = 'true' ]; then # This is the parameter after --arg-file. -- cwells
                next_arg=''
                ARG_FILE="${script_arg}"
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

if [ -s "${rocinante_template}/Bastillefile" ]; then
    # Ignore blank lines and comments. -- cwells
    SCRIPT=$(awk '{ if (substr($0, length, 1) == "\\") { printf "%s", substr($0, 1, length-1); } else { print $0; } }' "${rocinante_template}/Bastillefile" | grep -v '^[[:blank:]]*$' | grep -v '^[[:blank:]]*#')
    SKIP_ARGS=""

    IFS='
'
    set -f
    for line in ${SCRIPT}; do
        # First word converted to lowercase is the Bastille command. -- cwells
        cmd=$(echo "${line}" | awk '{print tolower($1);}')
        # Rest of the line with "arg" variables replaced will be the arguments. -- cwells
        args=$(echo "${line}" | awk -F '[ ]' '{$1=""; sub(/^ */, ""); print;}' | eval "sed ${ARG_REPLACEMENTS}")

        # Skip any args that don't have a value
        for arg in ${SKIP_ARGS}; do
            if echo "${line}" | grep -qo "\${${arg}}"; then
                continue
            fi
        done

        # Apply overrides for commands/aliases and arguments. -- cwells
        case ${cmd} in
            arg+)
                arg_name=$(get_arg_name "${args}")
                arg_value=$(get_arg_value "${args}" "$@")
                if [ -z "${arg_value}" ]; then
                    error_exit "[ERROR]: No value provided for mandatory arg: ${arg_name}"
                else
                    ARG_REPLACEMENTS="${ARG_REPLACEMENTS} -e 's/\${${arg_name}}/${arg_value}/g'"
                fi
                continue
                ;;
            arg) # This is a template argument definition. -- cwells
                arg_name=$(get_arg_name "${args}")
                arg_value=$(get_arg_value "${args}" "$@")
                if [ -z "${arg_value}" ]; then
                    warn "[WARNING]: No value provided for arg: ${arg_name}"
                    SKIP_ARGS=$(printf '%s\n%s' "${SKIP_ARGS}" "${arg_name}")
                else
                    # Build a list of sed commands like this: -e 's/${username}/root/g' -e 's/${domain}/example.com/g'
                    ARG_REPLACEMENTS="${ARG_REPLACEMENTS} -e 's/\${${arg_name}}/${arg_value}/g'"
                fi
                continue
                ;;
            cmd)
                # Escape single-quotes in the command being executed. -- cwells
                args=$(echo "${args}" | sed "s/'/'\\\\''/g")
                # Allow redirection within the jail. -- cwells
                args="'${args}'"
                ;;
            cp|copy)
                cmd='cp'
                # Convert relative "from" path into absolute path inside the template directory. -- cwells
                if [ "${args%${args#?}}" != '/' ] && [ "${args%${args#??}}" != '"/' ]; then
                    args="${rocinante_template}/${args}"
                fi
                ;;
            fstab|mount)
                cmd='mount' ;;
            include)
                cmd='template' ;;
            overlay)
                cmd='cp'
                args="${rocinante_template}/${args} /"
                ;;
            pkg)
                args="install -y ${args}" ;;
            render) # This is a path to one or more files needing arguments replaced by values. -- cwells
                render ${args}
                continue
                ;;
            lif|lineinfile|line_in_file)
                line_in_file ${args}
                continue
                ;;
        esac

        if ! eval "rocinante ${cmd} ${args}"; then
            set +f
            unset IFS
            error_exit "Failed to execute command: ${cmd}"
        fi

    done
    set +f
    unset IFS
fi

info "\nTemplate applied: ${TEMPLATE}\n"
