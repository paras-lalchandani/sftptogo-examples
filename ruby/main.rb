require 'net/sftp'
require 'uri'

class SFTPClient
  attr_reader :session

  def initialize(sftp_url)
    # Get SFTP To Go URL from environment
    uri           = URI.parse(sftp_url)
    @host         = uri.host
    @user         = uri.user
    @port         = uri.port || 22 # Defaults to Port 22
    # Password is optional. 
    @password     = uri.password
    # If no password was set, ssh-agent will be used to detect private/public key authentication.
    # An array of file names of private keys to use for publickey authentication can also be used.
    @keys         = []

    puts "Connecting to #{@host} ...\n"
    @session         = Net::SFTP.start(
      @host, 
      @user, 
      password: @password,
      port: @port,
      keys: @keys,
      keys_only: false
    )
    puts "--> Done.\n\n"
  rescue Exception => e
    puts "Failed to parse SFTP To Go URL: #{e}"
  end

  # List all files
  # Requires remote read permissions.
  def list_files(remote_dir)
    session.dir.foreach(remote_dir) do |entry|
      # entry: https://www.rubydoc.info/gems/net-sftp/Net/SFTP/Protocol/V04/Name
      puts entry.longname
    end
  end

  def entries(remote_dir)
    session.dir.foreach(remote_dir) do |entry|
      # entry: https://www.rubydoc.info/gems/net-sftp/Net/SFTP/Protocol/V04/Name
      yield entry
    end
  end

  # Get remote file directly to a buffer
  # Requires remote read permissions.
  def get(remote_file)
    download(remote_file, nil, options)
  end

  # Open a remote file to a pseudo-IO with the given mode (r - read, w - write)
  # Requires remote read permissions.
  def open(remote_file, flags = 'r')
    # File operations
    # https://www.rubydoc.info/gems/net-sftp/2.0.5/Net/SFTP/Operations/File
    session.file.open(remote_file, flags) do |io|
      yield io
    end
  end

  # Upload local file to remote file
  # Requires remote write permissions.
  def upload(local_file, remote_file, options = {})
    session.upload!(local_file, remote_file, options)
  end

  # Download local file to remote file
  # Requires remote read permissions.
  def download(remote_file, local_file, options = {})
    session.download!(remote_file, local_file, options)
  end
end

if __FILE__ == $PROGRAM_NAME
  # Create SFTP Client to connect to SFTP To Go's server
  client = SFTPClient.new(ENV['SFTPTOGO_URL'])

  #
  # List working directory files
  #
  puts "Listing home directory ...\n"
  client.entries('.') do |entry|
    puts entry.longname
  end
  puts "--> Done.\n\n"

  remote_file = "./example.txt"
  local_file  = "./download.txt"
  #
  # Write directly to a remote file
  #
  puts "Writing some sample text to #{remote_file} remote file ...\n"
  client.open(remote_file, "w") do |f|
    f.puts "Hello from SFTP To Go 👋\n"
  end
  puts "--> Done.\n\n"

  #
  # Download the newly created remote file
  #
  puts "Downloading #{remote_file} remote file to #{local_file} local file ...\n"
  client.download(remote_file, local_file)
  puts "--> Done.\n\n"

  #
  # Upload local file to a new remote path
  #
  puts "Uploading #{local_file} to a copy remote file ...\n"
  client.upload(local_file, "#{remote_file}.copy")
  puts "--> Done.\n\n"
  
  #### 
  # 
  # CSV processing example
  #
  ####
  require 'csv'

  #
  # Write directly to a remote CSV file
  #
  puts "Writing some CSV data to #{remote_file} remote file ...\n"
  remote_file = "./example.csv"
  client.open(remote_file, "w") do |f|
    f.puts "a,b,c,d"
    f.puts "1,2,3,4"
    f.puts "5,6,7,8"
  end
  puts "--> Done.\n\n"

  #
  # Process the remote CSV file as a String IO
  #
  puts "Processing #{remote_file} remote file as CSV ...\n"
  io = StringIO.new
  # Adjust :read_size to the maximum number of bytes to read at a time from the source. 
  data = client.download(remote_file, io.puts, read_size: 32_000)
  csv = CSV.new(data.strip, headers: true)
  csv.each do |row|
    # Now print each row
    puts row.fields.to_csv(col_sep: ' | ')
  end
  puts "--> Done.\n\n"
end