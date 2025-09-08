FROM ubuntu:latest
RUN apt-get update && apt-get install -y npm
RUN npm install -g @anthropic-ai/claude-code
WORKDIR /app
COPY . /app
CMD ["claude"]