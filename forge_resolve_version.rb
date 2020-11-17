#!/opt/puppetlabs/puppet/bin/ruby

require 'net/https'
require 'uri'
require 'json'
require 'optparse'

class ForgeModule
  attr_accessor :name, :current_version, :latest_version, :original, :found, :depr, :deps

  def initialize
    @name            = ''
    @current_version = ''
    @latest_version  = ''
    @original        = false
    @found           = true
    @depr            = false
    @deps            = []
  end

  def return_line(mod)
    return "mod '#{mod.name}', '#{mod.latest_version}'"
  end

  def warn_nf(mod)
    return "Warning: #{mod.name} was not found"
  end

  def warn_depr(mod)
    return "Warning: #{mod.name} is deprecated"
  end

end

class ForgeVersions

  attr_accessor :mods_read, :lines, :data

  def initialize
    @mods_read  = {}
    @lines      = []
    @data       = {}
  end

  def get_mod_name(mod)
    if mod =~ /^\s*mod\s+('|")(\w+[\/-]\w+)('|"),\s+\S+/
      return $2
    elsif mod =~ /^\s*mod\s+('|")(\w+[\/-]\w+)('|")$/
      return $2
    end
  end

  def get_mod_ver(mod)
    if mod =~ /('|")([0-9].+)('|")/
      return $2
    end
  end

  def is_depr?(ver)
    ver == '999.999.999'
  end

  def mod_exists?(mod, data)
    o = false
    data.each do |d|
      o = (d.name == mod)
      break if (o == true)
    end
    return o
  end


  def read_puppetfile(input)
    mods_read = {}
    lines = []
    # Read modules from Puppetfile
    File.open(input, "r") do |fh|
      fh.each_line do |line|
        line.chomp!
        name = get_mod_name(line)
        if name
          ver = get_mod_ver(line)
          mods_read[name] = ver unless mods_read.keys.include? name
        else
          lines.push(line)
        end
      end
    end
    return mods_read, lines
  end

  # Arg: Array with list of modules 'author/name'
  # Ret: Array of ForgeModule objects
  def load_modules(mods)
    data = []
    # Search retrieved modules
    puts "#### Go get some tea while I process the Puppetfile ####"
    mods.each do |mod, ver|
      _mod = mod.gsub(/\//,'-')
      m = ForgeModule.new
      m, data = findModuleData(_mod, data)
      m.current_version = ver || ""
      m.original = true
      data.push(m) unless mod_exists?(_mod,data)
    end
    return data
  end

  # Arg: String containing name of module 'author/name'
  # Ret: ForgeModule object populated
  def findModuleData(mod, data)
    m = ForgeModule.new
    m.name = mod
    url = "https://forgeapi.puppet.com:443/v3/modules/#{mod}"
    uri = URI.parse(url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(uri.request_uri, {'User-Agent' => 'test'})
    response = http.request(request)

    if response.code == '200'
      parsed = JSON.parse(response.body)
      if parsed["current_release"] != nil
        m.found = true
        m.latest_version = parsed["current_release"]["version"]
        m.depr = is_depr?(parsed["current_release"]["version"])
        deps = parsed["current_release"]["metadata"]["dependencies"]
        if deps.any? and ! m.depr
          deps.each do |dep_mod|
            name = dep_mod['name'].gsub(/\//,'-')
            m.deps.push(name)
            unless mod_exists?(name,data)
              n, data = findModuleData(name, data)
              data.push(n)
            end
          end
        end
      else
        m.found = false
      end
    else
      m.found = false 
    end
    return m, data
  end
end

# Methods needed to get args and pretty print the objects
def parse_options()
  # Get arguments from CLI
  options = {}
  help = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0}"
    opts.on('-i [/path/to/original/Puppetfile]', '--input [/path/to/original/Puppetfile', "Path to original Puppetfile") do |i|
      options[:input] = i
    end
    opts.on('-o [/path/to/new/Puppetfile]', '--output [/path/to/new/Puppetfile]', "Path to new and improved Puppetfile") do |o|
      options[:output] = o
    end
    opts.on('-h', '--help', 'Display this help') do
      puts opts
      exit
    end
  end
  help.parse!
  return options, help
end

def validate_options(options, help)
  # Validate arguments
  input = options[:input]
  output = options[:output] || 'Puppetfile'
  outdir = File.dirname(output)

  unless input
    puts "ERROR: input is a mandatory argument"
    puts help
    exit 2
  end

  unless File.file?(input)
    puts "ERROR: #{input} does not exist"
    puts help
    exit 2
  end

  unless File.directory?(outdir)
    puts "ERROR: #{outdir} does not exist"
    puts help
    exit 2
  end

  return input, output, outdir
end

def write_response(output, lines, data)
  # Write Forge line
  forge = lines.grep(/^forge/i)
  File.open(output, "w") do |fh|
    if forge.any? 
      fh.puts forge.first
      fh.puts ""
    end

    # Create some filtered arrays
    upgraded = data.select { |m| ((! m.current_version.empty?) and (m.found) and (! m.depr) and (m.current_version != m.latest_version)) }
    added = data.select { |m| ! m.original }
    not_found = data.select { |m| ! m.found }
    deprecated = data.select { |m| m.depr }

    # Write Puppet file
    data.each do |mod|
      if mod.current_version and mod.found and ! mod.depr
        fh.puts mod.return_line(mod)
      end
    end

    # Now build the output
    # First let's show upgraded modules
    if ! upgraded.empty?
      puts "\n\n#### These modules have been upgraded ####"
      upgraded.each do |u|
        puts "Module #{u.name} - #{u.current_version} -> #{u.latest_version}"
      end
    end

    # Show added modules
    if ! added.empty?
      puts "\n\n#### These modules have been added ####"
      added.each do |a|
        puts "Module #{a.name} #{a.latest_version}"
      end
    end

    # Warnings time
    if ! not_found.empty?
      puts "\n\n#### Modules not found and removed from Puppetfile ####"
      not_found.each do |n|
        puts "Module #{n.name}"
      end
    end

    if ! deprecated.empty?
      puts "\n\n#### Deprecated modules removed from Puppetfile ####"
      deprecated.each do |d|
        puts "Module #{d.name}"
      end
    end

    # Write the non-forge lines
    fh.puts lines - forge
    puts "\n#### Your Puppetfile is now available at #{output} ####\n\n"
  end
end

# Set variables
options, help = parse_options()
input, output = validate_options(options, help)
f = ForgeVersions.new

f.mods_read, f.lines = f.read_puppetfile(input)
f.data = f.load_modules(f.mods_read)

write_response(output, f.lines, f.data)
exit 0
