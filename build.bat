@echo off
set includes=-I C:/strawberry/perl/lib -I ./lib -I ./lib/Openkore -I ./lib/Openkore/deps
set modules=%modules% -M Filter::Crypto::Decrypt 
set modules=%modules% -M unicore\Heavy.pl
set modules=%modules% -M utf8_heavy.pl
set modules=%modules% -M Actor
set modules=%modules% -M Actor::Monster
set modules=%modules% -M Actor::NPC
set modules=%modules% -M Actor::Party
set modules=%modules% -M Actor::Pet
set modules=%modules% -M Actor::Player
set modules=%modules% -M Actor::Portal
set modules=%modules% -M Actor::Slave
set modules=%modules% -M Actor::Unknown
set modules=%modules% -M Actor::You
set modules=%modules% -M AI
set modules=%modules% -M AutoLoader
set modules=%modules% -M Base::Server
set modules=%modules% -M Base::Server::Client
set modules=%modules% -M Bus::MessageParser
set modules=%modules% -M Bus::Messages
set modules=%modules% -M Carp
set modules=%modules% -M Carp::Assert
set modules=%modules% -M Class::Data::Inheritable
set modules=%modules% -M Compress::Raw::Zlib
set modules=%modules% -M Compress::Zlib
set modules=%modules% -M Config
set modules=%modules% -M Cwd
set modules=%modules% -M Data::Dumper
set modules=%modules% -M Devel::StackTrace
set modules=%modules% -M Digest::base
set modules=%modules% -M Digest::MD5
set modules=%modules% -M DynaLoader
set modules=%modules% -M Encode
set modules=%modules% -M Encode::Alias
set modules=%modules% -M Encode::Config
set modules=%modules% -M Encode::Encoding
set modules=%modules% -M Errno
set modules=%modules% -M Exception::Class
set modules=%modules% -M Exporter
set modules=%modules% -M Exporter::Heavy
set modules=%modules% -M FastUtils
set modules=%modules% -M Fcntl
set modules=%modules% -M Field
set modules=%modules% -M File::Basename
set modules=%modules% -M File::Glob
set modules=%modules% -M File::GlobMapper
set modules=%modules% -M File::Spec
set modules=%modules% -M File::Spec::Unix
set modules=%modules% -M File::Spec::Win32
set modules=%modules% -M FileHandle
set modules=%modules% -M FileParsers
set modules=%modules% -M FindBin
set modules=%modules% -M Getopt::Long
set modules=%modules% -M Globals

set modules=%modules% -M Hades::Config
set modules=%modules% -M Hades::Messages
set modules=%modules% -M Hades::ServerController
set modules=%modules% -M Hades::Statistics
set modules=%modules% -M Hades::TimedTasker

set modules=%modules% -M Hades::Packet
set modules=%modules% -M Hades::Logger

set modules=%modules% -M Hades::Packet::GameGuardReply

set modules=%modules% -M Hades::RagnarokServer::Client

set modules=%modules% -M Hades::RequestServer::Request
set modules=%modules% -M Hades::RequestServer::RequestQueue
set modules=%modules% -M Hades::RequestServer::RequestManager

set modules=%modules% -M Hades::Task::Reaper
set modules=%modules% -M Hades::Task::Reconfig
set modules=%modules% -M Hades::Task::Title

set modules=%modules% -M Hades::ThirdParty::Pushover

set modules=%modules% -M I18N
set modules=%modules% -M Interface
set modules=%modules% -M InventoryList
set modules=%modules% -M IO
set modules=%modules% -M IO::Compress::Adapter::Deflate
set modules=%modules% -M IO::Compress::Base
set modules=%modules% -M IO::Compress::Base::Common
set modules=%modules% -M IO::Compress::Gzip
set modules=%modules% -M IO::Compress::Gzip::Constants
set modules=%modules% -M IO::Compress::RawDeflate
set modules=%modules% -M IO::Compress::Zlib::Extra
set modules=%modules% -M IO::File
set modules=%modules% -M IO::Handle
set modules=%modules% -M IO::Seekable
set modules=%modules% -M IO::Socket
set modules=%modules% -M IO::Socket::INET
set modules=%modules% -M IO::Socket::UNIX
set modules=%modules% -M IO::Uncompress::Adapter::Inflate
set modules=%modules% -M IO::Uncompress::Base
set modules=%modules% -M IO::Uncompress::Gunzip
set modules=%modules% -M IO::Uncompress::RawInflate
set modules=%modules% -M List::MoreUtils
set modules=%modules% -M List::Util
set modules=%modules% -M Log
set modules=%modules% -M Math::BigInt
set modules=%modules% -M Math::BigInt::Calc
set modules=%modules% -M Math::Complex
set modules=%modules% -M Math::Trig
set modules=%modules% -M Misc
set modules=%modules% -M Modules
set modules=%modules% -M Network
set modules=%modules% -M Network::MessageTokenizer
set modules=%modules% -M Network::PacketParser
set modules=%modules% -M Network::Send
set modules=%modules% -M PerlIO::encoding
set modules=%modules% -M Plugins
set modules=%modules% -M Poseidon::Config
set modules=%modules% -M Poseidon::QueryServer
set modules=%modules% -M Poseidon::RagnarokServer
set modules=%modules% -M POSIX
set modules=%modules% -M Scalar::Util
set modules=%modules% -M SelectSaver
set modules=%modules% -M SelfLoader
set modules=%modules% -M Settings
set modules=%modules% -M Skill
set modules=%modules% -M Socket
set modules=%modules% -M Storable
set modules=%modules% -M Symbol
set modules=%modules% -M Task
set modules=%modules% -M Task::Chained
set modules=%modules% -M Task::Function
set modules=%modules% -M Task::Timeout
set modules=%modules% -M Task::Wait
set modules=%modules% -M Task::WithSubtask
set modules=%modules% -M Text::Balanced
set modules=%modules% -M Text::Tabs
set modules=%modules% -M Text::Wrap
set modules=%modules% -M Tie::Hash
set modules=%modules% -M Time::HiRes
set modules=%modules% -M Translation
set modules=%modules% -M UNIVERSAL
set modules=%modules% -M Utils
set modules=%modules% -M Utils::Assert
set modules=%modules% -M Utils::CallbackList
set modules=%modules% -M Utils::Crypton
set modules=%modules% -M Utils::DataStructures
set modules=%modules% -M Utils::Exceptions
set modules=%modules% -M Utils::ObjectList
set modules=%modules% -M Utils::Set
set modules=%modules% -M Utils::TextReader
set modules=%modules% -M Win32
set modules=%modules% -M Win32::Console
set modules=%modules% -M XSLoader
set modules=%modules% -M LWP::UserAgent


rem set resources=-a hades.banner -a ./resources/HADES_Icon.png;resources/HADES_Icon.png 	-a ./conf/recvpackets.txt;conf/recvpackets.txt -a ./conf/servertypes.txt;conf/servertypes.txt
@echo on
echo BUILD EXE
pp -o built/hades_server.exe hades_start.pl -f Crypto -F Crypto -z 9 %includes% %modules%

REM -M File::Path
pause