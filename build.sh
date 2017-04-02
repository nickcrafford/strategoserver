# Gather and compile deps
rm -rf _build
rm -rf dist
./rebar3 compile
mv _build/default/lib/ dist/
rm -rf _build

# Compile
mkdir dist/strategoserver/
mkdir dist/strategoserver/ebin/
cd src
erlc -o ../dist/strategoserver/ebin/ *.erl
cp *.app ../dist/strategoserver/ebin/
cp *.hrl ../dist/strategoserver/ebin/
cd ..