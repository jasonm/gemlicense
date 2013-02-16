class Library
  attr_accessor :license_filename, :readme_filename, :license_text, :readme_text, :library_name

  def initialize(options = {})
    options.each do |key, value|
      self.send("#{key}=", value)
    end
  end
end

class FilesystemLicenseIdentifier
  attr_reader :identifier

  def self.identify_path(path)
    @path = path
    fs_identifier = new(path)
    fs_identifier.identifier
  end

  private

  def initialize(path)
    @path = path
    identify
  end

  def identify
    library_name = File.basename(@path)

    # TODO: handle multiple license/readme files per repo, e.g. multi-lang like nokogiri
    license_filename = Dir["#{@path}/*"].detect { |fn| File.basename(fn) =~ /license|licence|copying|gpl/i }
    readme_filename  = Dir["#{@path}/*"].detect { |fn| File.basename(fn) =~ /readme/i }

    license_text = File.open(license_filename).read if license_filename
    readme_text = File.open(readme_filename).read if readme_filename

    library = Library.new({
      library_name: library_name,
      license_filename: license_filename,
      readme_filename: readme_filename,
      license_text: license_text,
      readme_text: readme_text
    })

    @identifier = LicenseIdentifier.new(library)
  end
end

class LicenseIdentifier
  attr_reader :license_name, :source, :copyright_holders

  def initialize(library)
    @library = library
    identify
  end

  def library_name
    @library.library_name
  end

  private

  def license_filename; @library.license_filename; end
  def readme_filename;  @library.readme_filename;  end
  def license_text;     @library.license_text;     end
  def readme_text;      @library.readme_text;      end

  def identify
    if license_filename
      @copyright_holders = license_text.split("\n").select { |line| line =~ /copyright.*\d\d\d\d/i }
    else
      @copyright_holders = []
    end

    if license_filename =~ /MIT/i
      @license_name = "MIT"
      @source = "License filename: #{license_filename}"
    elsif license_text =~ /MIT License/i
      @license_name = "MIT"
      @source = "License text inside: #{license_filename}"
    elsif license_text =~ /GNU Lesser General Public License version 3/i
      @license_name = "GPLv3"
      @source = "License text inside: #{license_filename}"
    elsif license_text =~ /Apache License.*Version 2.0/mi
      @license_name = "Apache 2.0"
      @source = "License text inside: #{license_filename}"
    elsif license_text && license_text.gsub(/\s/,'').include?('under either the terms of the GPL version 2 (see the file GPL), or the conditions below ("Ruby License")'.gsub(/\s/, ''))
      @license_name = "Ruby and GPL2"
      @source = "License text inside: #{license_filename}"
    elsif references_gplv3_license?(license_text)
      @license_name = "GPL3"
      @source = "License text inside: #{license_filename}"
    elsif contains_mit_license?(license_text)
      @license_name = "MIT"
      @source = "Full license text inside: #{license_filename}"
    elsif contains_mit_license?(readme_text)
      @license_name = "MIT"
      @source = "Full license text inside: #{readme_filename}"
    elsif contains_zlib_license?(license_text)
      @license_name = "zlib"
      @source = "Full license text inside: #{license_filename}"
    elsif contains_bsd2clause_license?(license_text)
      @license_name = "BSD 2-Clause"
      @source = "Full license text inside: #{license_filename}"
    elsif contains_gpl2_license?(license_text)
      @license_name = "GPL2"
      @source = "Full license text inside: #{license_filename}"
    elsif readme_text =~ /MIT License/i
      @license_name = "MIT"
      @source = "License referenced inside: #{readme_filename}"
    elsif readme_text && readme_text.include?("http://opensource.org/licenses/mit-license.html")
      @license_name = "MIT"
      @source = "License linked from: #{readme_filename}"
    elsif references_ruby_and_gpl2?(license_text)
      @license_name = "Ruby and GPL2"
      @source = "License references inside: #{license_filename}"
    elsif references_ruby_and_gpl2?(readme_text)
      @license_name = "Ruby and GPL2"
      @source = "License references inside: #{readme_filename}"
    elsif readme_text =~ /distributed under the same license as ruby./
      @license_name = "Ruby"
      @source = "License referenced inside: #{readme_filename}"
    else
      @license_name = nil
      @source = [license_filename, readme_filename].join(", ")
    end
  end

  def contains_mit_license?(text)
    @mit_text ||= File.open(File.join(File.dirname(__FILE__), "sample-mit-license.txt")).read.split("\n").join("")
    @mit_text2 ||= File.open(File.join(File.dirname(__FILE__), "sample-mit-license-without-copyrightholder-liability.txt")).read.split("\n").join("")

    contains_ignoring_whitespace?(text, @mit_text) ||
      contains_ignoring_whitespace?(text, @mit_text2)
  end

  def contains_zlib_license?(text)
    @zlib_text ||= File.open(File.join(File.dirname(__FILE__), "sample-zlib-license.txt")).read.split("\n").join("")
    contains_ignoring_whitespace?(text, @zlib_text)
  end

  def contains_bsd2clause_license?(text)
    @bsd2clause_text ||= File.open(File.join(File.dirname(__FILE__), "sample-bsd-2clause-license.txt")).read.split("\n").join("")
    contains_ignoring_whitespace?(text, @bsd2clause_text)
  end

  def contains_gpl2_license?(text)
    @gpl2_text ||= File.open(File.join(File.dirname(__FILE__), "sample-gpl2-license.txt")).read.split("\n").join("")
    contains_ignoring_whitespace?(text, @gpl2_text)
  end

  def references_ruby_and_gpl2?(text)
    text =~ /the Ruby license and the GPL2/ ||
      (allows_gpl_or_other?(text) && contains_ruby_license_text?(text))
  end

  def allows_gpl_or_other?(text)
    text =~ %r{You can redistribute it and/or modify it under either the terms of the GPL.*or the conditions below:}m
  end

  def contains_ruby_license_text?(text)
    @ruby_license_text ||= File.open(File.join(File.dirname(__FILE__), "sample-ruby-license.txt")).read.split("\n").join("")
    @ruby_license_text2 ||= File.open(File.join(File.dirname(__FILE__), "sample-ruby-license2.txt")).read.split("\n").join("")
    contains_ignoring_whitespace?(text, @ruby_license_text) ||
      contains_ignoring_whitespace?(text, @ruby_license_text2)
  end

  def references_gplv3_license?(text)
    gpl_text = 'GNU General Public License as published by the Free Software Foundation, either version 3 of the License'
    contains_ignoring_whitespace?(text, gpl_text)
  end

  def contains_ignoring_whitespace?(a, b)
    a && a.gsub(/\s/, '').include?(b.gsub(/\s/, ''))
  end
end
