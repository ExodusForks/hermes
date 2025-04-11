Steps to build for iOS:

```
(((install xcode + open it and install ios/mac frameworks)))
(((install brew)))
brew install cmake ninja ruby
echo 'export PATH="/user/local/opt/ruby/bin:$PATH"' >> ~/.zshrc
sudo gem install cocoapods
mkdir -p /tmp/hermes/output
git clone https://github.com/ExodusMovement/hermes.git
cd hermes
./build.sh
tar -zcvf ios.tar.gz destroot hermes-engine.podspec
shasum -a 256 ios.tar.gz > ios.tar.gz.shasum
```
