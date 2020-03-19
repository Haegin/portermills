.PHONY: dev start build

dev: node_modules
	yarn dev

start: node_modules
	yarn start

build: node_modules
	yarn build

node_modules:
	yarn install
