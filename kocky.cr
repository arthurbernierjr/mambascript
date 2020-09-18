require "http/server"
# 
server = HTTP::Server.new do |context|
  context.response.content_type = "text/html"
  context.response.print "<h1>Hello World! This is Kofu and Crystal at #{Time.local}</h1>"
end

address = server.bind_tcp 8000
puts "Listening on http://#{address}"
server.listen
