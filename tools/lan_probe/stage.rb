#!/usr/bin/env ruby
# Isolated non-game probe, copied from the exact production transport sources.
require 'fileutils'
require 'digest'
require 'json'

root = File.expand_path('../..', __dir__)
destination = ARGV.fetch(0)
abort 'Use a fresh staging directory' if File.exist?(destination)
files = %w[scripts/network/lan_transport.gd scripts/network/lan_probe_session.gd
           scripts/ui/network/lan_probe.gd scenes/network/LanProbe.tscn
           res/fonts/NotoSansCJKsc-Regular.otf res/art/app_icon/app_icon_1024.png
           tests/current/SichuanLanTransportRunner.gd]
files.each do |relative|
  source = File.join(root, relative)
  target = File.join(destination, relative)
  FileUtils.mkdir_p(File.dirname(target))
  FileUtils.cp(source, target)
end
FileUtils.cp(File.join(__dir__, 'project.godot'), destination)
FileUtils.cp(File.join(__dir__, 'export_presets.cfg'), destination)
FileUtils.mkdir_p(File.join(destination, 'tools'))
FileUtils.cp(File.join(__dir__, 'export_ios.gd'), File.join(destination, 'tools/export_ios.gd'))
puts JSON.generate({destination: destination, files: files.to_h { |p| [p, Digest::SHA256.file(File.join(destination, p)).hexdigest] }})
