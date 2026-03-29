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
    # Parse arguments: env name is the non-option arg; scope can be --global/--session
    # or legacy positional link/env (deprecated)
    local env_name="" named_scope="" positional_scope="" do_add=0
    for arg in "$@"; do
        case "$arg" in
            --add)     do_add=1 ;;
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

    if (( do_add )); then
        if [[ -z "$env_name" ]]; then
            echo "${fg[red]}Error: ase --add requires an environment name${reset_color}"
            return 1
        fi
        local env_dir="${HOME}/.aws/aws-envs/${env_name}"
        if [[ -d "$env_dir" ]]; then
            echo "${fg[red]}Error: environment '${env_name}' already exists${reset_color}"
            return 1
        fi
        mkdir -p "$env_dir"
        touch "${env_dir}/config" "${env_dir}/credentials"
        echo "${fg[green]}Created environment '${env_name}'${reset_color}"

        echo -n "Does this environment use AWS SSO? [y/N] "
        read -r _ase_use_sso
        if [[ "$_ase_use_sso" =~ ^[Yy]$ ]]; then
            local _ase_sso_start_url _ase_sso_session_name _ase_sso_account_id _ase_sso_role_name _ase_sso_region

            echo -n "SSO start URL (e.g. https://myorg.awsapps.com/start): "
            read -r _ase_sso_start_url

            # Derive session name from org prefix in https://<org>.awsapps.com/start
            if [[ "$_ase_sso_start_url" =~ ^https://([^.]+)\.awsapps\.com/ ]]; then
                _ase_sso_session_name="${match[1]}"
            else
                _ase_sso_session_name="sso"
            fi

            echo -n "Main account ID (for sso-browser): "
            read -r _ase_sso_account_id

            echo -n "Role name for sso-browser profile [AdministratorAccess]: "
            read -r _ase_sso_role_name
            _ase_sso_role_name="${_ase_sso_role_name:-AdministratorAccess}"

            echo -n "AWS region [eu-west-1]: "
            read -r _ase_sso_region
            _ase_sso_region="${_ase_sso_region:-eu-west-1}"

            cat > "${env_dir}/config" << EOF
[sso-session ${_ase_sso_session_name}]
sso_region = ${_ase_sso_region}
sso_start_url = ${_ase_sso_start_url}
sso_registration_scopes = sso:account:access

[profile sso-browser]
sso_session = ${_ase_sso_session_name}
sso_account_id = ${_ase_sso_account_id}
sso_role_name = ${_ase_sso_role_name}
region = ${_ase_sso_region}
EOF
            echo "${fg[green]}SSO config written (session: ${_ase_sso_session_name})${reset_color}"
            echo "Next run the command below to log in and generate credentials for this environment:"
            echo "ase --session ${env_name} && aws sso login --profile sso-browser && uvx sso-config-generator"
        fi

        return 0
    fi

    _check_aws_envs || return 1

    local -a available_environments
    available_environments=($(_aws_environments))

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

        echo "Usage: ase [--global|--session] <env-name>  or  ase --add <env-name>"
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