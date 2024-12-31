client:
    cd client && gleam run -m lustre/dev start --tailwind-entry=base.css --proxy-from=/api --proxy-to=http://localhost:3000

server:
    cd server && bin/rails server
