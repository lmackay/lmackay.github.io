require 'yaml'
require 'rubygems'
require 'jekyll'
require 'rmagick'
require 'find'
 
desc 'Build and send to dev server'
task :build, :opt do |t, args|
    
    opt = args[:opt]
    if opt then
    puts opt
        if ("full".casecmp opt) == 0 then
            generateGalleries[all]
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

desc 'Generate Galleries
      @param path - optional argument defining a gallery file to rebuild. 
                    If no value is selected then user will be prompted to 
                    choose from a list of found items. Special value of "all"
                    can be used to rebuild all galleries.'
task :generateGalleries, :path do |t, args|
  puts 'Generating Galleries'
  
  #define variables
  galleryDir = "gallery"
  fullImgDir = 'photos/full'
    
    
  galleries = findGalleryFiles(fullImgDir)
    
  gallery = args[:path]
  galleryBuilt = false
  if gallery then
    if ("all".casecmp gallery) == 0 then
      #Clean out directories
      FileUtils.rm Dir.glob("#{gallery_dir}/*")
      FileUtils.rm_rf Dir.glob("photos/thumbs/*")
      FileUtils.rm_rf Dir.glob("photos/large/*")

      #Build the individual gallery files
      galleries.each do |foundGallery|
        generateGallery(foundGallery, fullImgDir, galleryDir)
        galleryBuilt = true
      end
    else 
      # try to find a matching file in galleries
      found = false
      galleries.each do |foundGallery|
        if (foundGallery.casecmp path) == 0 then
          found = true
          #use the one we found
          path = foundGallery
        end
      end
      
      #do something with the result
      if found
        #it was in our list, produce the gallery file
        generateGallery(path, fullImgDir, galleryDir)
        
        galleryBuilt = true
      else
        #not found! Prompt for option
        choice = chooseFile(galleries)
        puts "Choice: #{choice}"
        
        if choice
          generateGallery(choice, fullImgDir, galleryDir)
          galleryBuilt = true
        else
          puts "Unknown file #{path}. Known: #{galleries}."
        end
      end
    end
  else
    #Prompt for option
    choice = chooseFile(galleries)
    puts "Choice: #{choice}"
    
    if choice
      generateGallery(choice, fullImgDir, galleryDir)
      galleryBuilt = true
    else
      puts "No choice made. "
    end
  end
  
  if galleryBuilt
    #rebuild the index
    buildPhotosetsIndex(galleries, fullImgDir, 'index.html')
  end
  
  puts 'Done'
end

desc 'Rebuild gallery and image versions from the supplied gallery.yaml file.
      @param sourcePath - the YAML file to build the gallery from.
      @param galleryRootDir - The directory that the gallery base dir is relative to.
      @param destPath - the path to the directory to create the gallery file in.'
def generateGallery(sourcePath, galleryRootDir, destPath)
  
  puts "Producing gallery file for #{sourcePath}"
        
  fileContents = produceGalleryYaml(sourcePath, galleryRootDir)
        
  # Write the file for the single gallery page. 
  titleSlug = encodeSlug(fileContents['title'])
  writeYAML(fileContents, "#{galleryRootDir}/#{titleSlug}.html")
        
  #Generate smaller versions of images
  FileUtils.mkdir_p("photos/large/#{fileContents['basedir']}")
  FileUtils.mkdir_p("photos/thumbs/#{fileContents['basedir']}")
        
  fileContents['images'].each do |imageFile|
        
    origImagePath = "#{galleryRootDir}/#{fileContents['basedir']}/#{imageFile['file']}"
    puts "Producing smaller versions of #{imageFile['file']}..."
        
    # thumbnail. This will use a section of the centre of the image
    i = Magick::Image.read(origImagePath).first
    i.resize_to_fill(250,250, Magick::CenterGravity).write("photos/thumbs/#{fileContents['basedir']}/#{imageFile['file']}")
            
    # large. This will use the full image
    i = Magick::Image.read(origImagePath).first
    i.resize_to_fit(1024, 1024).write("photos/large/#{fileContents['basedir']}/#{imageFile['file']}")
  end
end

def upload
    puts 'Sending to server...'
    sh 'rsync -avz --delete ../lmk_built_site/  david@dev-lamp.local:/home/wwwroot/lauraphoto/'
    puts 'Sent'

end

desc 'Creates a user selection menu from a given set of options.
      @param options - collection of options the user can choose from.'
def chooseFile(options)
  options.each_with_index { |f,i| puts "#{i+1}: #{f}" }
  print "> "
  num = STDIN.gets
  return false if num =~ /^[a-z ]*$/i
  file = options[num.to_i - 1]
end

def ask(message, valid_options)
  return true if $skipask
  if valid_options
    answer = get_stdin("#{message} #{valid_options.delete_if{|opt| opt == ''}.to_s.gsub(/"/, '').gsub(/, /,'/')} ") while !valid_options.map{|opt| opt.nil? ? '' : opt.upcase }.include?(answer.nil? ? answer : answer.upcase)
  else
    answer = get_stdin(message)
  end
  answer
end

desc 'Build the main page of photosets.
      @param galleryFiles - Array of the gallery files to include.
      @param galleryRootDir - The directory that the gallery base dir is relative to
      @param filePath - the file to write to.'
def buildPhotosetsIndex(galleryFiles, galleryRootDir, filePath)
    
  # Load the individual gallery pages 
  allGalleries = []
  galleryFiles.each do |file|
    fileContents = produceGalleryYaml(file, galleryRootDir) 
    allGalleries.push(fileContents)
  end
  
  #Regenerate the index page
  indexContents = Hash.new
  indexContents['layout'] = 'photosets'
  indexContents['sets'] = []
  
  allGalleries.sort_by{|e| e['order']}
  allGalleries.each do |item|
        
    setDefinition = Hash.new
    setDefinition['title'] = item['title']
    setDefinition['url'] = item['permalink']
        
    item['images'].each do |image|
      if image['main']
        setDefinition['pictureUrl'] = "#{item['basedir']}/#{image['file']}"
      end
    end
        
    indexContents['sets'].push(setDefinition) 
  end

  #Write the file
  writeYAML(indexContents, filePath)
end

desc 'Produce the YAML file contents for a gallery from the source file.'
def produceGalleryYaml(sourceFile, galleryRootDir) 
  fileContents = YAML.load(File.open(sourceFile))
        
  title = fileContents['title']
  titleSlug = encodeSlug(title)
  
  fileContents['layout'] = 'gallery'
  fileContents['permalink'] = "/gallery/#{titleSlug}"
  fileContents['lightbox'] = "#{title}"
  fileContents['basedir'] = sourceFile.gsub("#{galleryRootDir}/",'').gsub('/gallery.yaml','')
        
  return fileContents;
  
end

desc 'Create URL safe "slug" text
      @param text - the text to convert'
def encodeSlug(text)
  return text.gsub(' ','').gsub('&amp;', '&').downcase
end

desc 'Recusively find all the "gallery.yaml" files in the supplied directory.'
def findGalleryFiles(basedir)
  gallery_file_paths = []
  Find.find(basedir) do |path|
    gallery_file_paths << path if path =~ /gallery.yaml$/
  end
  return gallery_file_paths
end

desc 'Dump currentCollection to a file at the supplied path.'
def writeYAML(contentCollection, filePath)
  #Write the file     
  File.open(filePath, 'w+') do |new_file|
    YAML.dump(contentCollection, new_file)
    # SimpleYAML is missing this, jekyll will complain without it.
    new_file.write('---')
  end
end
