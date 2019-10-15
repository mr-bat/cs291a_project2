# frozen_string_literal: true

require 'sinatra'
require 'digest'
require 'json'
require 'google/cloud/storage'
storage = Google::Cloud::Storage.new(project_id: 'cs291-f19')
bucket = storage.bucket 'cs291_project2', skip_lookup: true

def validate_internal_sha256(string)
  !string.match(%r{\A[a-zA-Z0-9]{2}/[a-zA-Z0-9]{2}/[a-zA-Z0-9]{60}\z}).nil?
end

def normalize_hash(string)
  unless validate_internal_sha256 string
    raise 'Bad Argument at translate_hash_to_internal'
  end

  string.gsub('/', '')
end

def internalize_string(string)
  string.dup.insert(2, '/').insert(5, '/')
end

def file_exist(hash)
  storage = Google::Cloud::Storage.new(project_id: 'cs291-f19')
  bucket = storage.bucket 'cs291_project2', skip_lookup: true
  files = bucket.files
  files.all do |file|
    return true if hash == file.name || internalize_string(hash) == file.name
  end
end

get '/' do
  redirect to('/files/')
end

get '/files/' do
  valid_hashes = []
  files = bucket.files
  files.all do |file|
    if validate_internal_sha256 file.name
      valid_hashes << normalize_hash(file.name)
    end
  end
  content_type :json
  valid_hashes.to_json
end

post '/files/' do
  unless params &&
         params[:file] &&
         params[:file][:tempfile] &&
         params[:file][:filename]
    @error = 'No file selected'
    return 422
  end
  unless params[:file][:tempfile].size < 1024 * 1024
    @error = 'File too large'
    return 422
  end

  filename = params[:file][:filename]
  content = params[:file][:tempfile].read
  hash = Digest::SHA256.hexdigest content

  return 409 if file_exist hash

  puts hash
  puts content
  puts filename

  bucket.create_file StringIO.new(content), internalize_string(hash)
  bucket.create_file StringIO.new(request.env['CONTENT_TYPE']), hash
  response = {
    'uploaded' => hash
  }
  content_type :json
  [201, response.to_json]
end
