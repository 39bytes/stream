# stream

A small personal micro-blogging site.
![image](https://github.com/user-attachments/assets/da443ad6-ddc5-4c41-9757-552957c00e1b)

Supports Markdown, code syntax highlighting, MathJax, and pasting images from clipboard.

### Running
Install [just](https://github.com/casey/just), [Gleam](https://gleam.run/) and [Rails](https://rubyonrails.org/).

Then set up the environment variables.
For the client:
```
cd client
mv .env.example .env
```

For the server, set up and configure a GitHub OAuth app, and set the environment variables accordingly.
```
cd server
mv .env.example .env
```

Then, from the root, run the client and the server.
```
just client
just server
```

The dev server will be running at `http://localhost:1234`.

### Prior Art
Heavily inspired by my friend [Liam's project of the same name](https://github.com/terror/stream).
