/// MusicBrainz recording IDs for "Super Sonic" (boss) music tracks.
/// When a track with one of these MBIDs is playing, the SuperSonic aura
/// easter egg is shown around the album art.
library;

// ── SuperSonic MBIDs ─────────────────────────────────────────────────────────

/// Set of MusicBrainz recording IDs that trigger the SuperSonic easter egg.
const Set<String> superSonicMbids = {
  // Game soundtracks

  // --------- Sonic 3 ---------
  // Boss the Boss
  '513036cb-b338-4aa5-b773-cba9d3e69c6d',

  // --------- Sonic the Fighters ---------
  // SUPER SONIC ~ Everything
  '53a76801-78aa-409c-995b-d15f59b46890',

  // --------- Sonic Adventure ---------
  // Open Your Heart
  '64ae0737-3e88-4545-ab4d-fe8d3b7750a9',
  '76016564-69ac-4ffc-857f-6c90448a7323',
  '60a69cc1-70fd-4619-92f4-6988c95c20a8',
  'c555e190-0540-42af-9595-ce9bc6fb2055',
  'ef333f91-f4df-44ee-8b21-ad6625e6ca27',
  '3eb8e1be-bc11-4e02-820f-960bb29810a4',
  '1e4af6cc-020e-47f9-9c2f-85148187fad2',

  // --------- Sonic Adventure 2 ---------
  // Live and Learn
  '92cba593-8281-486f-9684-d38c900c2391',
  '2184fa39-935f-4369-82b7-91d599bd09d7',
  '7e726ed2-2544-4b81-9da1-c9d4aeac36b5',
  'a45fcdb9-200d-4625-9e83-623d1500a8cc',
  '7d49c325-a523-4873-bdd9-2e856e936fe4',
  'd99b85fb-8b42-4016-bd10-55bd51e40944',
  'ce0353fb-ddcb-40ec-8516-bb9008298749',
  '9f4a56da-d7cb-4215-9c8e-c30468f860c3',
  '9f455583-9ad3-4953-bead-95b3092f2e91',

  // --------- Sonic Heroes ---------
  // What I'm Made Of
  '1a615b88-5414-460e-8dcb-5f6cf9407cd5',
  '4e89a7a6-6073-418f-be13-18f212edbf6a',

  // --------- Sonic Rush ---------
  // Wrapped in Black
  '997d567d-edbe-45a1-83d8-c3e073432b52',
  'a066def7-5d3c-4829-90f2-6e94501b5ec6',
  // Wrapped in Black (part 2)
  'd4c585dd-4668-43e8-a684-1d6c7222115f',

  // --------- Shadow the Hedgehog ---------
  // I Am... All Of Me / FINAL DOOM ver.
  'e5c9fa9b-ae4e-468d-bd88-3f43324cd06f',

  // --------- Sonic 06 ---------
  // Solaris Phase 1
  'e063d61c-5d5e-4791-95c7-a2ac7ed84771',
  // Solaris Phase 2
  'afd3eb2f-f03b-4c17-94db-4c8d9e8cdf43',

  // --------- Sonic Rush Adventure ---------
  // Boss - Deep Core
  '0a02250d-0626-4f6b-a9d6-51a2e7a7cdab',
  // Boss - Deep Core - Allegro
  'bf7d9a91-e306-4c32-92c2-c5aeee8d7d11',

  // --------- Sonic Unleashed ---------
  // Super Sonic vs. Perfect Dark Gaia
  '26c84d38-ce4c-45b7-a8c9-c15d15bd186e',

  // --------- Sonic Generations ---------
  // BOSS BATTLE : TIME EATER ver.1
  '8e02975a-744c-4c15-8f0b-eb27507ef05e',
  // BOSS BATTLE : TIME EATER ver.2
  'bdf43bd3-0d3d-4365-9108-3fe6fa72b48e',
  // BOSS BATTLE : TIME EATER - Final Attack
  'a69db060-e302-48b2-a3ba-b1d4fe490832',
  '5cee1da5-b0a5-436b-a8cc-6bac9cdc04bc',

  // --------- Sonic Mania ---------
  // Glimmering Gift - Super Transformation
  '7e4c79f0-f3f5-4ac1-9a77-cb98c74a7d0d',
  '65d290a9-1415-470e-8827-2c3973dfaad8',

  // --------- Sonic Frontiers ---------
  // Undefeatable
  'b05fab4d-8e83-46c5-a475-7ef2f75df1da',
  '52321364-90df-43a3-a691-b998c294f6e7',
  // Break Through it All
  '89f96a2c-1de0-4160-8b96-d12ed7dca0f3',
  '3e46cc50-3556-4aca-abd3-e918924582e1',
  // Find Your Flame
  '6a4955d9-22dd-47de-80e1-0f141baea6dc',
  'dfd39cd5-c35b-4bb9-b57a-27475b61b5bd',
  // I'm Here
  '07ef5bc8-c081-4757-b406-5e0eb5cbce6b',
  'a06742de-cdfc-40f7-9c54-1d8330a3061a',
  'c3392371-def6-4ca4-b691-411a39ec8e48',
  // I'm With You
  '64a70f8e-82ae-4389-8131-81263ae2dcbd',

  // --------- Sonic Superstars  ---------
  // Emerald Power: Super Sonic
  '5635e2ce-e519-4d47-87ca-cdb153060fe1',

  // Other soundtracks

  // --------- Sonic 30th Anniversary Symphony ---------
  // Open Your Heart
  'd4bbe964-54f6-487b-bfd7-14ba4a33f7b6',
  // I Am... All Of Me
  'c8402044-7257-459f-96a2-c311a106dc37',
  // Live & Learn
  '8cdb2e7a-3118-4bc5-979c-290fb7f26e1d',

  // --------- Sonic Movie 3 ---------
  // Live and Learn
  '577d8c0f-1d6b-4150-92ac-a18c5cec6470',
};

/// Returns true if the given MBID (case-insensitive) is a known SuperSonic
/// track.
bool isSuperSonicMusic(String? mbid) {
  if (mbid == null || mbid.isEmpty) return false;
  return superSonicMbids.contains(mbid.toLowerCase());
}
