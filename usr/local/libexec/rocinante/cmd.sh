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

cmd_usage() {
    error_exit "Usage: rocinante cmd [option(s)] ARGS"
}

# Handle options.
OPTION="-xc"
while [ "$#" -gt 0 ]; do
    case "${1}" in
        -h|--help|help)
            cmd_usage
            ;;
        -q|--quiet)
            OPTION="-c"
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
    cmd_usage
fi

# Execute CMD

info "\n[CMD]:"

sh "${OPTION}" "$@"

ERROR_CODE="$?"

info "${ERROR_CODE}"

return "${ERROR_CODE}"

echo
