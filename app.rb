# frozen_string_literal: true

require 'sinatra'
require 'digest'
require 'json'
require 'google/cloud/storage'
storage = Google::Cloud::Storage.new(project_id: 'cs291-f19')
bucket = storage.bucket 'cs291_project2', skip_lookup: true

def validate_internal_sha256(string)
  !string.match(%r{\A[a-fA-F0-9]{2}/[a-fA-F0-9]{2}/[a-fA-F0-9]{60}\z}).nil?
end

def validate_sha256(string)
  !string.match(%r{\A[a-fA-F0-9]{64}\z}).nil?
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
  unless params['file'] &&
         params['file']['filename'] &&
         params['file']['tempfile']
    return [422, 'No file selected']
  end
  unless params['file']['tempfile'].size <= 1024 * 1024
    return [422, 'File too large']
  end

  content = params[:file][:tempfile].read
  hash = Digest::SHA256.hexdigest content
  extracted_type = params[:file]['head'].split(/Content-Type: /)[1]
                                        .split
                                        .first

  return [409, 'File exist'] if file_exist hash

  bucket.create_file StringIO.new(content),
                     internalize_string(hash),
                     content_type: extracted_type
  response = {
    'uploaded' => hash
  }
  [201, response.to_json]
end

get '/files/:hash' do |hash|
  hash = hash.downcase
  return [422, 'Invalid hash'] unless validate_sha256 hash
  return [404, 'No such file'] unless file_exist hash

  file = bucket.file internalize_string(hash)
  content = file.download
  content.rewind

  content_type file.content_type
  content.read
end

delete '/files/:hash' do |hash|
  hash = hash.downcase
  return [422, 'Invalid hash'] unless validate_sha256 hash
  return [200, 'No such file or already deleted'] unless file_exist hash

  content = bucket.file internalize_string(hash)
  content.delete

  [200, 'File deleted']
end
