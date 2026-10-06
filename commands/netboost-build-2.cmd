COMMAND=if [ ! -f package.json ]; then cp -r "$HOME/terhux/repo/netboost-template/." "$HOME/netboost/"; fi; cd "$HOME/netboost" && npm install && npm test && npm run build
WORKDIR=/data/data/com.termux/files/home
APPROVED=true
