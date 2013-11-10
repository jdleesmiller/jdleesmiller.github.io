#
# Edits Eclipse's generated Makefiles to make them support a precompiled header.
#
# To use this script:
# 1. Create a file that includes the headers you want to precompile; this script
#    assumes that you use my_project/src/stdafx.h, but you can change the PCH
#    constant, below, if you want to do it differently.
# 2. Put this script in your project root.
# 3. Edit your project's properties; under C/C++ build, set the build command to
#      ruby ../cdtgch.rb
#    (the "../" is important because eclipse runs the script from the build
#    directory, and the script is in the project root).
# 4. Make sure your source files include "stdafx.h"; it's a good idea to make
#    this the first include.
# 5. Everything else should be as normal.
#
# Note that the script only allows you to have *one precompiled header file*.
# Note that you only get to use the gch in *one configuration*. 
#
# See
# http://jdleesmiller.blogspot.com/2009/10/amazing-ruby-precompiled-header-hack.html 
# for more info.
#

#
# Header file that you want to precompile.
# Path must be relative to the project root. 
# The directory containing the stdafx.h must contain at least one .cpp file.
#
PCH = 'src/stdafx.h'

# Look at existing makefile to see if it needs hacking; we will only rewrite
# it if necessary.
rewrite_makefile = false
makefile_lines = IO.readlines('makefile')
makefile_lines.each {|l| l.chomp!}

# Need to import dependency file for the pch. This has to happen after we've
# imported subdir.mk.
dep_line = "CPP_DEPS += #{PCH}.gch.d"
objects_line = makefile_lines.index("-include objects.mk")
raise "cannot find subdir.mk include line" unless objects_line
unless makefile_lines[objects_line+1] == dep_line
  makefile_lines.insert(objects_line+1, dep_line)
  rewrite_makefile = true
end

# Make all objects depend on the precompiled header (even if not all of them
# really do).
gch_o_rule = "$(OBJS):%.o:../#{PCH}.gch"
unless makefile_lines.member?(gch_o_rule)
  makefile_lines << ""
  makefile_lines << gch_o_rule
  makefile_lines << ""

  rewrite_makefile = true
end

# Look for the rule to build the gch. We need to use the same g++ arguments as
# everywhere else; we can get these from a subdir.mk file. The dependencies on
# the project files ensure that the PCH gets rebuilt when the project settings
# change; otherwise, this happens for all the other files, but not the PCH, for
# reasons that I don't fully understand.
gch_rule = "../#{PCH}.gch: ../#{PCH} ../.cproject ../.project"
unless makefile_lines.find {|l| l =~ /^#{gch_rule}/}
  # Need to look up the command in the subdir.mk file.
  subdir_mk = File.new(File.join(File.dirname(PCH),'subdir.mk')).read
  subdir_mk =~ /^(\tg\+\+.*)$/ or raise "cannot find g++ command in subdir.mk"
  cmd = $1

  # Make the command do dependencies for the gch file.
  cmd.gsub! /-MF"[^"]*"/, "-MF\"#{PCH}.gch.d\""
  cmd.gsub! /-MT"[^"]*"/, "-MT\"#{PCH}.gch.d\""

  # Append a rule for building the precompiled header.
  makefile_lines<<""
  makefile_lines<<"#{gch_rule}"
  makefile_lines<<cmd

  rewrite_makefile = true
end

# Add a command to the clean rule so we get rid of the gch-related files.
clean_line = (0...makefile_lines.size).find{|i| makefile_lines[i] =~ /^clean:/}
raise "couldn't find clean: line in makefile" unless clean_line
unless makefile_lines[clean_line+1] =~ /#{PCH}\.gch/
  makefile_lines.insert(clean_line+1,
    "\trm -f #{PCH}.gch.d ../#{PCH}.gch")
  rewrite_makefile = true
end

# Save changes, if any.
if rewrite_makefile
  File.open('makefile', 'w') do |f|
    f.write makefile_lines.join("\n")
  end
end

# Now run make.
exec "make", ARGV.join(' ')

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

