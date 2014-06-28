require 'nokogiri'
require 'open-uri'
require 'thread'
require 'pry'

$username = ARGV[0]
img_urls = Queue.new;
dl_urls = Queue.new;

if !Dir.exists? "downloads"
	Dir.mkdir "downloads"
end

if !Dir.exists? "downloads/#{$username}"
	Dir.mkdir "downloads/#{$username}"
end

def download_img (url)
	uri = URI.parse(url)
	filename = File.basename(uri.path)
	File.open("downloads/#{$username}/" + filename, "wb") do |saved_file|
		open(url, "rb") do |read_file|
			saved_file.write(read_file.read)
		end
	end
end

puts "*** Scanning pages for images..."
# on each page of the entire set, get the urls for all the images

(1..100).each do |pagenum|
	was_redirected = false
	page_url = "https://www.flickr.com/photos/#{$username}/page" + pagenum.to_s + "/"
	uri = open(page_url) do |resp|
		# if these urls don't match, there was a redirect--
		# meaning we reached the max page num already and can stop now
		if resp.base_uri.to_s != page_url
			was_redirected = true
		end

		page_string = resp.read
	end

	if was_redirected
		puts "*** Found #{pagenum} pages of images. Fetching original quality images..."
		break
	end

	doc = Nokogiri::HTML(uri)
	doc.css('.photo-click').each do |photo|
		img_urls.push("https://www.flickr.com" + photo.attribute('href').to_s + "sizes/o")
	end
end

# binding.pry

# on all the images, grab the original quality download location

workers_count = 12
workers = []
workers_count.times do |n|
	workers << Thread.new(n+1) do |my_n|
		while (img = img_urls.shift(true) rescue nil) do

			doc = Nokogiri::HTML(open(img))
			doc.css('a').each do |link|
				if link.to_s.include? "Download the Original size"
					dl_urls.push(link.attribute('href'))
					puts "Original img #{link.attribute('href')}"
					break
				end
			end
		end
	end
end

workers.each(&:join)

puts "*** Found #{dl_urls.length} images. Now downloading..."

workers = []
workers_count.times do |n|
	workers << Thread.new(n+1) do |my_n|
		while (dl = dl_urls.shift(true) rescue nil) do
			download_img(dl)
			puts "Downloaded #{dl}"
		end
	end
end

workers.each(&:join)

puts "*** Complete"
