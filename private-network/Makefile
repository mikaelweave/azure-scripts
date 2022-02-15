define PROJECT_HELP_MSG
Usage:
    make help               show this message
    make deploy             deploy infrastructure via terraform
	make destroy            destroy infrastructure via terraform
endef
export PROJECT_HELP_MSG

help:
	@echo "$$PROJECT_HELP_MSG" | less

deploy:
	bash ./scripts/deploy.sh

destroy:
	bash ./scripts/destroy.sh
