client:
    cd client && chmod +x gen_env.sh && ./gen_env.sh
    cd client && gleam run -m lustre/dev start --tailwind-entry=base.css --proxy-from=/api --proxy-to=http://localhost:3000

server:
    cd server && bin/rails server

build-image:
    docker build -t stream . --build-arg API_URL=http://localhost:80

run-container: build-image
   docker run -d -p 80:80 \
    -e RAILS_MASTER_KEY=$RAILS_MASTER_KEY \
    -e GITHUB_CLIENT_ID=$GITHUB_CLIENT_ID \
    -e GITHUB_CLIENT_SECRET=$GITHUB_CLIENT_SECRET \
    -e GITHUB_REDIRECT_URI=$GITHUB_REDIRECT_URI \
    --name stream stream
