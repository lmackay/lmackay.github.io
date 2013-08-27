require 'yaml'
require 'rubygems'
require 'jekyll'
# require 'rmagick'
 
def get_zemanta_terms(content)
  $stderr.puts "Querying Zemanta..."
  zemanta = Zemanta.new "lmwsm9styjveqhycabofusyk"
  suggests = zemanta.suggest(content)
  res = []
  suggests['keywords'].each {|k|
    res << k['name'].downcase.gsub(/\s*\(.*?\)/,'').strip if k['confidence'] > 0.02
  }
  res
end
 
desc "Add Zemanta keywords to post YAML"
task :add_keywords, :post do |t, args|
  file = args.post
  if File.exists?(file)
    # Split the post by --- to extract YAML headers
    contents = IO.read(file).split(/^---\s*$/)
    headers = YAML::load("---\n"+contents[1])
    content = contents[2].strip
    # skip adding keywords if it's already been done
    unless headers['keywords'] && headers['keywords'] != []
      begin
        $stderr.puts "getting terms for #{file}"
        # retrieve the suggested keywords
        keywords = get_zemanta_terms(content)
        # insert them in the YAML array
        headers['keywords'] = keywords
        # Dump the headers and contents back to the post
        File.open(file,'w+') {|file| file.puts YAML::dump(headers) + "---\n" + content + "\n"}
      rescue
        $stderr.puts "ERROR: #{file}"
      end
    else
      puts "Skipped: post already has keywords header"
    end
  else
    puts "No such file."
  end
end

# https://gist.github.com/stammy/790778
# Using multi-word tags support from http://tesoriere.com/2010/08/25/automatically-generated-tags-and-tag-clouds-with-jekyll--multiple-word-tags-allowed-/
# If using with jekyll gem, remove bits loop and site.read_bits('') and add require 'rubygems' and require 'jekyll'
# Using full HTML instead of layout include to manually set different page title (tag, not tag_slug) and canonical URL in header
 
 
desc 'Build tags pages'
task :build_with_tags do
#     sh 'rm -rf _site'
    
    puts "Generating tags..."

    include Jekyll::Filters
 
    options = Jekyll.configuration({})
    site = Jekyll::Site.new(options)
    site.read_posts('')
 
    # nuke old tags pages, recreate
    FileUtils.rm_rf("tags")
    FileUtils.mkdir_p("tags")
    
    #Regenerate the index page
    html = <<-HTML
---
layout: main
title: Tags
---

<h2>Tags</h2>
<ul class="tagList">
{% for tag in site.tags %}
	<li><a href="/tags/{{ tag | first | downcase | replace:' ','' | replace:'&amp;','&'}}">{{ tag | first }} <span>({{ tag | last | size }})</span></a></li>			
{% endfor %}
</ul>
HTML
    File.open("tags/index.html", 'w+') do |file|
        file.puts html
    end
 
    site.tags.sort.each do |tag, posts|
	  # generate slug-friendly tag
      tag_slug = tag.gsub(' ','').gsub('&amp;', '&').downcase 
 
      html = <<-HTML
---
layout: main
title: Tagged #{tag}
permalink: /tags/#{tag_slug}/
---
{% assign tagName='#{tag_slug}' %}
{% include tag_page %}
HTML
      File.open("tags/#{tag_slug}.html", 'w+') do |file|
        file.puts html
      end
    end
 
    puts 'Done.'
end

desc 'Build category pages'
task :build_with_categories do
    
    puts "Generating categories..."

    include Jekyll::Filters
 
    options = Jekyll.configuration({})
    site = Jekyll::Site.new(options)
    site.read_posts('')
 
    # nuke old pages, recreate
    FileUtils.rm_rf("categories")
    FileUtils.mkdir_p("categories")
    
    #Regenerate the index page
    html = <<-HTML
---
layout: main
title: Categories
---

<h2>Tags</h2>
<ul class="catList">
{% for cat in site.categories %}
	<li><a href="/categories/{{ cat | first | downcase | replace:' ','' | replace:'&amp;','&'}}">{{ cat | first }} <span>({{ cat | last | size }})</span></a></li>			
{% endfor %}
</ul>
HTML
    File.open("categories/index.html", 'w+') do |file|
        file.puts html
    end
 
    site.categories.sort.each do |cat, posts|
	  # generate slug-friendly category
      cat_slug = cat.gsub(' ','').gsub('&amp;', '&').downcase 
 
      html = <<-HTML
---
layout: main
title: In Category #{cat}
permalink: /categories/#{cat_slug}/
---
{% assign catName='#{cat_slug}' %}
{% include category_page %}
HTML
      File.open("categories/#{cat_slug}.html", 'w+') do |file|
        file.puts html
      end
    end
 
    puts 'Done.'
end

desc 'Build and send to dev server'
task :build do
    jekyll
    upload
    puts 'Done.'
end

def jekyll
  puts 'Building...'
  sh 'lessc css/main.less css/main.css'
  sh 'jekyll build --drafts'
  sh 'touch _site/.htaccess'
  puts 'Build Complete'
end

task :upload do
    upload
end

desc 'Generate Thumbnails'
task :generateThumbs do
    puts 'Generating Thumbnails'
    generateThumbs
    puts 'Done'
end

def generateThumbs

    photoDir = Dir.open "photos" 
    
    FileUtils.rm_rf("photos/thumbs")
    FileUtils.mkdir_p("photos/thumbs")

    photoDir.each do |file|
        i = Magick::Image.read(file).first
        i.resize_to_fill(250,250, Magick::CenterGravity).write("photos/thumbs/#{file}-tb.jpg")
    end
end

def upload
    puts 'Sending to server...'
    sh 'rsync -avz --delete _site/ david@dev-lamp.local:/home/wwwroot/lauraphoto/'
    puts 'Sent'

end
