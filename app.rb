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
  puts params
  unless params['file'] &&
         # params[:file]&.key?('filename') &&
         # params[:file]&.key?('tempfile')
         params['file']['filename'] &&
         params['file']['tempfile']
    @error = 'No file selected'
    # puts params
    # puts params['file']
    # puts params['file']['filename']
    # puts params[:file][:tempfile]
    return 422
  end
  unless params['file']['tempfile'].size <= 1024 * 1024
    @error = 'File too large'
    return 422
  end

  puts params[:file]['head']
  puts params[:file]['head']
  filename = params[:file][:filename]
  content = params[:file][:tempfile].read
  hash = Digest::SHA256.hexdigest content
  extracted_type = params[:file]['head'].split(/Content-Type: /)[1]

  return 409 if file_exist hash

  # puts hash
  # puts content
  # puts filename
  puts extracted_type

  bucket.create_file StringIO.new(content), internalize_string(hash)
  bucket.create_file StringIO.new(extracted_type), hash
  response = {
    'uploaded' => hash
  }
  [201, response.to_json]
end

get '/files/:hash' do |hash|
  hash = hash.downcase
  puts hash
  puts validate_sha256 hash
  return 422 unless validate_sha256 hash
  return 404 unless file_exist hash

  content = (bucket.file internalize_string(hash)).download
  type = (bucket.file hash).download

  content.rewind
  type.rewind

  final_content = content.read
  final_type = type.read
  puts final_type

  content_type final_type
  final_content
end

delete '/files/:hash' do |hash|
  hash = hash.downcase
  return 422 unless validate_sha256 hash
  return 200 unless file_exist hash

  puts hash
  content = bucket.file internalize_string(hash)
  type = bucket.file hash

  content.delete
  type.delete

  return 200
  # rescue
  #   return 203
end
