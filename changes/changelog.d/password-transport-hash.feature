First-party login (`POST /api/v1/users/token/`) now requires a domain-separated SHA-256 password digest instead of plaintext; Tayra hashes the password before send.
