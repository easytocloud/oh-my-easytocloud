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
    # post_install runs outside sandbox, so HOME is the real home directory
    ohmyzsh = ENV["HOME"] + "/.oh-my-zsh"
    return unless Dir.exist?(ohmyzsh)

    system "mkdir", "-p", ohmyzsh + "/custom/plugins/easytocloud"
    system "cp", "-R", (share/"oh-my-easytocloud/plugins/easytocloud").to_s + "/.", ohmyzsh + "/custom/plugins/easytocloud/"

    system "mkdir", "-p", ohmyzsh + "/custom/themes"
    system "cp", (share/"oh-my-easytocloud/themes/easytocloud.zsh-theme").to_s, ohmyzsh + "/custom/themes/"
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
