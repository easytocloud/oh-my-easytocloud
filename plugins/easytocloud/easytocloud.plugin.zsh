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

function _get_current_env() {
    local _aws_env
    _aws_env=$(echo ${AWS_CONFIG_FILE:-$(readlink ~/.aws/config)} | rev | cut -f2 -d '/' | rev)
    if [[ "$_aws_env" == ".aws" ]]; then
        _aws_env=""
    fi
    echo $_aws_env
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
    if [[ -z "${available_environments[(r)$1]}" ]]; then
        echo "Usage: ase <env-name> [link|env]"
        echo "Available environments:"
        _aws_environments | sed 's/^/  /'
        return 1
    fi
    
    if [[ ! -L ~/.aws/config || ! -L ~/.aws/credentials ]]; then
        echo "${fg[red]}~/.aws/config and ~/.aws/credentials must be symlinks"
        return 1
    fi
    
    local method=${2:-"link"}
    AWS_ENV=$1

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
        export AWS_CONFIG_FILE=~"/.aws/aws-envs/${AWS_ENV}/config"
        export AWS_SHARED_CREDENTIALS_FILE=~"/.aws/aws-envs/${AWS_ENV}/credentials"
    fi

    if aws_profiles | grep -q '^default$'; then
        export AWS_PROFILE=default
    else
        export AWS_PROFILE=$(aws_profiles | head -n 1)
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
RPROMPT=""