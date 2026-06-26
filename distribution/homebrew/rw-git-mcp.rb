class RwGitMcp < Formula
  desc "Model Context Protocol (MCP) server for rw-git"
  homepage "https://github.com/gbrandtio/rw-git"
  version "2.2.1"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/gbrandtio/rw-git/releases/download/v#{version}/rw_git_mcp_macos_arm64"
      sha256 "REPLACE_WITH_SHA256" # Optional, but good practice
    elsif Hardware::CPU.intel?
      url "https://github.com/gbrandtio/rw-git/releases/download/v#{version}/rw_git_mcp_macos_x64"
      sha256 "REPLACE_WITH_SHA256" # Optional, but good practice
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/gbrandtio/rw-git/releases/download/v#{version}/rw_git_mcp_linux_x64"
      sha256 "REPLACE_WITH_SHA256" # Optional, but good practice
    end
  end

  def install
    if OS.mac? && Hardware::CPU.arm?
      bin.install "rw_git_mcp_macos_arm64" => "rw-git-mcp"
    elsif OS.mac? && Hardware::CPU.intel?
      bin.install "rw_git_mcp_macos_x64" => "rw-git-mcp"
    elsif OS.linux? && Hardware::CPU.intel?
      bin.install "rw_git_mcp_linux_x64" => "rw-git-mcp"
    end
  end

  test do
    system "#{bin}/rw-git-mcp", "--version" # Assuming there's a version flag, if not just verify it runs
  end
end
