ifndef DOCKER_REPO
        $(error DOCKER_REPO env variable needs to be set)
endif

IMAGE_NAME=demo-nginx-rtmp
IMAGE_TAG=latest

all: build push

build:
	docker build -t ${DOCKER_REPO}${IMAGE_NAME}:${IMAGE_TAG} ./

push: build
	docker push ${DOCKER_REPO}${IMAGE_NAME}:${IMAGE_TAG}

