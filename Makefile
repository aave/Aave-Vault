-include .env

.EXPORT_ALL_VARIABLES:
MAKEFLAGS += --no-print-directory

default:
	forge fmt && forge build


simulate:
	@forge script script/DeployUSDeVault.s.sol --fork-url $(PROVIDER_URL) -vvvvv

deploy:
	@forge script script/DeployUSDeVault.s.sol --rpc-url $(PROVIDER_URL) --account deployerKey --sender $(DEPLOYER_ADDRESS) --broadcast --slow --verify -vvvv


# Override default `test` and `coverage` targets
.PHONY: test coverage
