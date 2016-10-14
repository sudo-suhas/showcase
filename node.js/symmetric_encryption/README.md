# Symmetric encryption
Encryption and deryption with URL safe characters.

## Usage
```js
const crypter = require('./crypter');
const text = 'Everything\'s gonna be 200 OK!';

const encrypted = crypter.encrypt(text);
console.log(encrypted); // 'saDMrUH3J72nRIU0umL_AA..lOcTpqmhJLEtGiRZLHSbMwqOYptoiTHImzZQU8IX5zg.'
const decrypted = crypter.decrypt(encrypted);
console.log(decrypted); // 'Everything's gonna be 200 OK!'
```

Because of the initialization vector, the encrypted text is different each time for the same text.

```
> const crypter = require('./crypter');

> const text = 'Everything\'s gonna be 200 OK!';

> console.log(crypter.encrypt(text));
O7R0_qX2Yt3iD8XYbCRH1g..qQFHlQxF2htxfthuLY4hGWtrFkGvH5OhFetyiYp79Hc.

> console.log(crypter.encrypt(text));
wo0mPafmb4sWoGLx8sPMCQ..lVziUHlS4v0HJgCUz8tT_Y1a4QO4hyHPUbiCYlFlx2A.

> console.log(crypter.encrypt(text));
qqYEW2m-v2zWTvs24SFFnQ..JH2KrO0wgwK2Mjv7pirV_tVNHuOxxirCFTZjDl34qQo.

> console.log(crypter.encrypt(text));
49ZupTKxSLseKhmAYg4lrg..0rzkfzM50nxysBsmIYLDFZRfkP6VJhMz02WQku-RU7w.

> console.log(crypter.encrypt(text));
NZi4o9iwoQgfB5cAKnJWsg..wPcwbbGV-5q2yjyukbdjscQ0hi-vve2C8BSQ2wglXNw.
```