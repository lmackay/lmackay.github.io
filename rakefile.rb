require 'yaml'
require 'rubygems'
require 'jekyll'
require 'rmagick'
require 'find'
require 'yaml'
 
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
task :build, :opt do |t, args|
    
    opt = args[:opt]
    if opt then
    puts opt
        if ("full".casecmp opt) == 0 then
            generateGalleries
        end
    end

    jekyll
    upload
    puts 'Done.'
end

def jekyll
  puts 'Building...'
  sh 'lessc css/main.less css/main.css'
  sh 'jekyll build --drafts -d ../lmk_built_site'
  sh 'touch ../dwi_built_site/.htaccess'  
  puts 'Build Complete'
end

task :upload do
    upload
end

desc 'Generate Galleries'
task :generateGalleries do
    puts 'Generating Galleries'
    generateGalleries
    puts 'Done'
end

desc 'Rebuild galleries and image versions from the gallery.yaml files in the photos/full directory'
def generateGalleries

    gallery_dir = "gallery"
    full_img_dir = 'photos/full'
    #Clean out directories
    FileUtils.rm Dir.glob("#{gallery_dir}/*")
    FileUtils.rm_rf Dir.glob("photos/thumbs/*")
    FileUtils.rm_rf Dir.glob("photos/large/*")
    
    # Find all the "gallery.yaml" files that are in the full_img_dir.
    gallery_file_paths = []
    Find.find(full_img_dir) do |path|
      gallery_file_paths << path if path =~ /gallery.yaml$/
    end
    
    # Print this list
    puts gallery_file_paths
    
    all_galleries = []
    # Generate the individual gallery pages 
    gallery_file_paths.each do |file|
        puts "File: #{file}"
        file_contents = YAML.load(File.open(file))
        #puts file_contents
        
        title = file_contents['title']
        title_slug = title.gsub(' ','').gsub('&amp;', '&').downcase 
        
        file_contents['layout'] = 'gallery'
        file_contents['permalink'] = "/gallery/#{title_slug}"
        file_contents['lightbox'] = "#{title}"
        file_contents['basedir'] = file.gsub("#{full_img_dir}/",'').gsub('/gallery.yaml','')
        
        all_galleries.push(file_contents)
        
        # Write the file for the single gallery page. 
        File.open("gallery/#{title_slug}.html", 'w+') do |new_file|
            YAML.dump(file_contents, new_file)
            # SimpleYAML is missing this, jekyll will complain without it.
            new_file.write('---')
        end
        
        #Generate smaller versions
        FileUtils.mkdir_p("photos/large/#{file_contents['basedir']}")
        FileUtils.mkdir_p("photos/thumbs/#{file_contents['basedir']}")
        
        file_contents['images'].each do |image_file|
        
            image_path = "#{full_img_dir}/#{file_contents['basedir']}/#{image_file['file']}"
        
            # thumbnail. This will use a section of the centre of the image
            i = Magick::Image.read(image_path).first
            i.resize_to_fill(250,250, Magick::CenterGravity).write("photos/thumbs/#{file_contents['basedir']}/#{image_file['file']}")
            
            # large. This will use the full image
            i = Magick::Image.read(image_path).first
            i.resize_to_fit(1024, 1024).write("photos/large/#{file_contents['basedir']}/#{image_file['file']}")
        end
        
        
    end
    
    #Regenerate the index page
    index_contents = Hash.new
    index_contents['layout'] = 'photosets'
    index_contents['sets'] = []
    
    all_galleries.sort_by{|e| e['order']}
    all_galleries.each do |item|
        
        set_def = Hash.new
        set_def['title'] = item['title']
        set_def['url'] = item['permalink']
        
        item['images'].each do |image|
            if image['main']
                basedir = item['basedir']
                img_file = image['file']
                set_def['pictureUrl'] = "#{basedir}/#{img_file}"
            end
        end
        
        index_contents['sets'].push(set_def) 
    end

    #Write the file     
    File.open("index.html", 'w+') do |new_file|
        YAML.dump(index_contents, new_file)
        # SimpleYAML is missing this, jekyll will complain without it.
        new_file.write('---')
    end
    
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
    sh 'rsync -avz --delete ../lmk_built_site/  david@dev-lamp.local:/home/wwwroot/lauraphoto/'
    puts 'Sent'

end
