#
# easytocloud modification to default aws plugin


export ZSH_THEME_AWS_PROFILE_PREFIX="%K{11}%F{black} "
export ZSH_THEME_AWS_PROFILE_SUFFIX=""
export ZSH_THEME_AWS_DIVIDER=" | "

source ${ZSH:-${HOME}/.oh-my-zsh}/plugins/aws/aws.plugin.zsh

# Internal functions
function _check_aws_envs() {
    if [[ ! -d ~/.aws/aws-envs ]]; then
        echo "${fg[red]}No AWS environments found. Please create ~/.aws/aws-envs directory and add your environments."
        return 1
    fi
}

function _aws_environments() {
    ls ~/.aws/aws-envs
}

function _get_global_env() {
    local _aws_env
    _aws_env=$(readlink ~/.aws/config 2>/dev/null | rev | cut -f2 -d '/' | rev)
    [[ "$_aws_env" == ".aws" ]] && _aws_env=""
    echo "$_aws_env"
}

function _get_current_env() {
    local _aws_env
    _aws_env=$(echo "${AWS_CONFIG_FILE:-$(readlink ~/.aws/config 2>/dev/null)}" | rev | cut -f2 -d '/' | rev)
    [[ "$_aws_env" == ".aws" ]] && _aws_env=""
    echo "$_aws_env"
}

# Public functions
function age() {
    _get_current_env
}

function aws_environments() {
    _check_aws_envs || return 1
    _aws_environments
}

function ase() {
    _check_aws_envs || return 1

    local -a available_environments
    available_environments=($(_aws_environments))

    # Parse arguments: env name is the non-option arg; scope can be --global/--session
    # or legacy positional link/env (deprecated)
    local env_name="" named_scope="" positional_scope=""
    for arg in "$@"; do
        case "$arg" in
            --global)  named_scope="global" ;;
            --session) named_scope="session" ;;
            link)      positional_scope="link" ;;
            env)       positional_scope="env" ;;
            --*)
                echo "${fg[red]}Error: unknown option '$arg'${reset_color}"
                return 1
                ;;
            *)
                if [[ -n "$env_name" ]]; then
                    echo "${fg[red]}Error: multiple environment names specified${reset_color}"
                    return 1
                fi
                env_name="$arg"
                ;;
        esac
    done

    # Conflict: both a named scope option and a legacy positional scope
    if [[ -n "$named_scope" && -n "$positional_scope" ]]; then
        echo "${fg[red]}Error: conflicting scope: '--${named_scope}' and '${positional_scope}' cannot be used together${reset_color}"
        return 1
    fi

    # Deprecation warning for legacy positional options
    if [[ -n "$positional_scope" ]]; then
        local replacement
        [[ "$positional_scope" == "link" ]] && replacement="--global" || replacement="--session"
        echo "${fg[yellow]}Warning: '${positional_scope}' is deprecated, use '${replacement}' instead${reset_color}" >&2
        named_scope="${replacement#--}"
    fi

    # Map user-facing scope to internal method (default: global -> link)
    local method
    case "${named_scope:-global}" in
        global)  method="link" ;;
        session) method="env" ;;
    esac

    if [[ -z "${available_environments[(r)$env_name]}" ]]; then
        local global_env session_env
        global_env=$(_get_global_env)
        session_env="${AWS_ENV}"

        echo "Usage: ase [--global|--session] <env-name>"
        echo "Available environments:"
        local env prefix
        for env in ${available_environments}; do
            if [[ "$env" == "$global_env" && "$env" == "$session_env" ]]; then
                prefix="${fg[green]}*${reset_color}"
            elif [[ "$env" == "$session_env" ]]; then
                prefix="${fg[yellow]}>${reset_color}"
            elif [[ "$env" == "$global_env" ]]; then
                prefix="${fg[blue]}~${reset_color}"
            else
                prefix=" "
            fi
            echo "  ${prefix} ${env}"
        done
        if [[ -n "$global_env" && -n "$session_env" && "$global_env" != "$session_env" ]]; then
            echo ""
            echo "  ${fg[green]}*${reset_color} = session & global  ${fg[yellow]}>${reset_color} = this session only  ${fg[blue]}~${reset_color} = global only"
        fi
        return 1
    fi

    if [[ ! -L ~/.aws/config || ! -L ~/.aws/credentials ]]; then
        echo "${fg[red]}~/.aws/config and ~/.aws/credentials must be symlinks${reset_color}"
        return 1
    fi

    AWS_ENV=$env_name

    if [[ "$method" == "link" ]]; then
        (
            cd ~/.aws
            rm config credentials
            ln -s aws-envs/${AWS_ENV}/config ~/.aws/config
            ln -s aws-envs/${AWS_ENV}/credentials ~/.aws/credentials
        )
        unset AWS_CONFIG_FILE
        unset AWS_SHARED_CREDENTIALS_FILE
    else
        export AWS_CONFIG_FILE="${HOME}/.aws/aws-envs/${AWS_ENV}/config"
        export AWS_SHARED_CREDENTIALS_FILE="${HOME}/.aws/aws-envs/${AWS_ENV}/credentials"
    fi

    local profiles
    profiles=$(aws_profiles)
    if echo "$profiles" | grep -q '^default$'; then
        export AWS_PROFILE=default
    else
        export AWS_PROFILE="${${(f)profiles}[1]}"
    fi
}

function acc() {
    unset AWS_PROFILE AWS_DEFAULT_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_ENV
}

function _ase_completion() {
    reply=($(_aws_environments 2>/dev/null))
}
compctl -K _ase_completion ase
# override AWS prompt
function aws_prompt_info() {
  local _aws_to_show
  local region="${AWS_REGION:-${AWS_DEFAULT_REGION:-$AWS_PROFILE_REGION}}"

  if [[ -n "$AWS_PROFILE" ]];then
    _aws_to_show+="${ZSH_THEME_AWS_PROFILE_PREFIX="<aws:"}${AWS_PROFILE}${ZSH_THEME_AWS_PROFILE_SUFFIX=">"}"
  fi

  local _AE=$(_get_current_env)
  if [[ -n "$_AE" ]]; then
    _aws_to_show+="${ZSH_THEME_AWS_DIVIDER="|"}${_AE} %k%f"
  fi

  #if [[ -n "$region" ]]; then
  #  [[ -n "$_aws_to_show" ]] && _aws_to_show+="${ZSH_THEME_AWS_DIVIDER=" "}"
  #  _aws_to_show+="${ZSH_THEME_AWS_REGION_PREFIX="<region:"}${region}${ZSH_THEME_AWS_REGION_SUFFIX=">"}"
  #fi

  echo "$_aws_to_show"
}
function _unset_aws_default_profile() {
    unset AWS_DEFAULT_PROFILE
}
autoload -U add-zsh-hook
add-zsh-hook precmd _unset_aws_default_profile
RPROMPT=""