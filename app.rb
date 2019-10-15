# frozen_string_literal: true

require 'sinatra'
require 'digest'
require 'json'
require 'google/cloud/storage'
storage = Google::Cloud::Storage.new(project_id: 'cs291-f19')
bucket = storage.bucket 'cs291_project2', skip_lookup: true

def validate_sha256(string)
  !string.match(/\A[a-zA-Z0-9]{2}\/[a-zA-Z0-9]{2}\/[a-zA-Z0-9]{60}\z/).nil?
end

get '/' do
  redirect to('/files/')
end

get '/files/' do
  valid_hashes = []
  files = bucket.files
  files.all do |file|
    valid_hashes << file.name.gsub('/','') if validate_sha256 file.name
  end
  print valid_hashes
  content_type :json
  valid_hashes.to_json
end

post '/upload' do
  unless params[:file] &&
         (tmpfile = params[:file][:tempfile]) &&
         (name = params[:file][:filename])
    @error = 'No file selected'
    return haml(:upload)
  end
  warn "Uploading file, original name #{name.inspect}"
  while blk = tmpfile.read(65_536)
    # here you would write it to its final location
    warn blk.inspect
  end
  'Upload complete'
end

post '/' do
  require 'pp'
  PP.pp request
  "POST\n"
end
