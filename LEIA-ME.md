# DodgeBall League (site)

Site do jogo, publicado no GitHub Pages: https://guilhermevictor59.github.io/dodgeball/ (o código do jogo fica no repositório privado dodgeballeague)

- `index.html`: página tela cheia com tela de carregamento no visual do jogo (troca a página padrão do Godot).
- `index.js`, `index.wasm`, `index.pck`, `index.audio*.js`: export Web do Godot 4 (sem threads, então não precisa de COOP/COEP).
- Para atualizar o jogo: exporte de novo no Godot e troque `index.pck` (e `index.wasm`/`index.js` se mudar a versão do Godot). Se o tamanho do `.pck` mudar, atualize `fileSizes` em `index.html`. Cada push no `main` publica sozinho.
- O online usa servidores MQTT públicos (lista de salas) + WebRTC direto entre navegadores; não precisa de servidor próprio.
