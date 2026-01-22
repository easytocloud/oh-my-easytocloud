# typed: true
# frozen_string_literal: true

class OhMyEasytocloud < Formula
  desc "Upgrade oh-my-zsh agnoster theme with aws_env in prompt"
  homepage "https://github.com/easytocloud/oh-my-easytocloud"
  url "https://github.com/easytocloud/oh-my-easytocloud/archive/refs/tags/v0.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"

  def install
    # Install to Homebrew's share directory (always works)
    (share/"oh-my-easytocloud/plugins/easytocloud").install Dir["plugins/easytocloud/*"]
    (share/"oh-my-easytocloud/themes").install "themes/easytocloud.zsh-theme"
    (share/"doc/oh-my-easytocloud").install "README.md"
  end

  def post_install
    ohmyzsh = Pathname(ENV["HOME"]) / ".oh-my-zsh"
    return unless ohmyzsh.exist?

    # Install plugin files
    plugin_dir = ohmyzsh / "custom/plugins/easytocloud"
    plugin_dir.rmtree if plugin_dir.exist?
    plugin_dir.mkpath
    (share/"oh-my-easytocloud/plugins/easytocloud").children.each do |file|
      cp file, plugin_dir
    end

    # Install theme file
    theme_dir = ohmyzsh / "custom/themes"
    theme_dir.mkpath
    cp share/"oh-my-easytocloud/themes/easytocloud.zsh-theme", theme_dir
  end

  def caveats
    <<~EOS
      The theme and plugin have been installed to ~/.oh-my-zsh/custom/

      To activate, set in your ~/.zshrc:
        ZSH_THEME="easytocloud"
        plugins=(... easytocloud ...)
    EOS
  end

  test do
    assert_predicate share/"oh-my-easytocloud/plugins/easytocloud/easytocloud.plugin.zsh", :exist?
    assert_predicate share/"oh-my-easytocloud/themes/easytocloud.zsh-theme", :exist?
  end
end
