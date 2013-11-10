#
# Helper script for using EtherPad with LaTeX.
#
# To run the demo, type
#
# rake demo.pdf
#
# which will grab the content from an EtherPad (which is editable by the
# public; the author disclaims all responsibility for its content) and
# compile it using latex.
#
# Most of this code is generic; you just need to change one line at the end.
#
# See
# http://jdleesmiller.blogspot.com/2009/05/amazing-ruby-rake-etherpad-latex.html
# for more info.
#
# UPDATES:
# 20090713: Now using the Etherpad export functions instead of the epview
#           application, which no longer seems to exist.
#

require 'rake/clean'
require 'net/http'
require 'uri'

CLEAN.include('*.dvi')
CLEAN.include('*.aux')
CLEAN.include('*.log')

# Get the plain text content of an etherpad.
def get_etherpad pad
  # Based on http://forums.etherpad.com/viewtopic.php?id=168
  url = URI.parse("http://etherpad.com/ep/pad/export/#{pad}/latest?format=txt")
  $stderr.print "Getting #{url}... "
  s = Net::HTTP.get(url)
  $stderr.puts "done."
  s.strip
end

# See etherpad_file.
class EtherpadFileTask < Rake::FileTask
  attr_accessor :pad

  def remote_pad
    @remote_pad = get_etherpad(pad) unless @remote_pad
    @remote_pad
  end

  def needed?
    return true unless File.exists?(name)
    local_pad = File.open(name) {|f| f.read}
    return remote_pad != local_pad
  end
end

#
# Task to copy an etherpad to a local file.
# Each time it is invoked, it checks whether the etherpad has changed; if it
# has, the local file is updated; if it hasn't, the local file is left alone.
#
def etherpad_file(file_name, pad, &block)
  eft = EtherpadFileTask.define_task({file_name => []}) do |t|
    raise unless t.remote_pad
    File.open(t.name, 'w') {|f| f.write(t.remote_pad)}
    $stderr.puts "Wrote pad #{t.pad} to #{t.name}."
  end
  eft.pad = pad
  eft
end

rule '.pdf' => %w(.tex) do |t|
  tex = t.prerequisites.first
  dvi = tex.sub(/\.tex$/,'.dvi')
  ps = tex.sub(/\.tex$/,'.ps')
  sh <<SH
latex #{tex}
latex #{tex}
latex #{tex}
dvips -o #{ps} #{dvi}
ps2pdf #{ps} #{t}
SH
end

desc "run demo!"
task 'demo.pdf'

#
# The code above is generic; the code below shows how to configure the task.
#
# This demo uses the etherpad at
# http://etherpad.com/iGkKC6cxGU
#
# Use your own pad ID (and local tex file name) below.
#

etherpad_file 'demo.tex', 'iGkKC6cxGU'

#
# Copyright (c) 2009 John Lees-Miller
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE. 
#

