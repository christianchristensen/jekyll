require 'rubygems'
require 'jekyll'
require 'fileutils'
require 'posterous'
require 'net/http'
require 'URI'

Posterous.config = {
  'username'  => ARGV[0],
  'password'  => ARGV[1],
  'api_token' => ARGV[2]
}

include Posterous

puts "all set"

FileUtils.mkdir_p "_posts"
FileUtils.mkdir_p "images"

site = Site.primary
page = 1
posts = site.posts(:page => page)

puts "made it so far"

def download_image(u)
	path = 'images/%s' % u.split('/')[-1]
	if !File.exists?(path)
  	url = URI.parse(u)
  	found = false 
  	until found 
  		host, port = url.host, url.port if url.host && url.port 
  		query = url.query ? url.query : ""
  		req = Net::HTTP::Get.new(url.path + '?' + query)
  		res = Net::HTTP.start(host, port) {|http|  http.request(req) } 
  		res.header['location'] ? url = URI.parse(res.header['location']) : found = true 
  	end 
  	open(path, "wb") do |file|
  		file.write(res.body)
  	end
	end
	path
end	

while posts.any?
	posts.each do |post|
	  puts post.inspect
		puts post.title
		if post.slug.nil?
		  post.slug = post.title.downcase.gsub(' ', '-')
	  end
		slug = post.slug.gsub('/', '-')
		date = Date.parse(post.display_date)
		published = !post.is_private
		name = "%02d-%02d-%02d-%s.html" % [date.year, date.month, date.day, slug]

		tags = post.tags.map do |t|
			t['name']
		end

		perm = URI::parse(post.full_url)

		# Get the relevant fields as a hash, delete empty fields and convert
		# to YAML for the header
		if perm.path == '/'
	    pp_permalink = "/index.html"
    else
      pp_permalink = perm.path + "/index.html"
    end
  
		data = {
			'permalink' => pp_permalink,
			'layout' => 'post',
			'title' => post.title.to_s,
			'published' => published,
			'categories' => tags,
		}.delete_if { |k,v| v.nil? || v == ''}.to_yaml

		content = post.body_html

		# awefull hack, do not use on vlog or podcast
		post.media[2]['images'].each do |img|
		  if !img.nil? && !img['full'].nil? && !img['full']['url'].nil?
  			path = download_image(img['full']['url'])
  			tag = "<img src=\"/%s\" alt=\"%s\" />" % [path, img['full']['caption']]
  			puts tag
  			begin
  				content[/\[\[posterous-content:[^\]]*\]\]/] = tag
  			rescue IndexError
  				puts "weird stuff happening"
  				content = content + "\n" + tag
  			end
			end
		end

		# Write out the data and content to file
		File.open("_posts/#{name}", "w") do |f|
			f.puts data
			f.puts "---"
			f.puts content
		end
	end

	page += 1
	posts = site.posts(:page => page)
end