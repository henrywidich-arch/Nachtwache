// Turns the raw ElevenLabs downloads into the game's sound set: picks the chosen variant,
// trims silence, mixes one-shots to mono, evens out loudness and writes 16-bit WAVs.
//   node tools/make_sounds.js <raw folder>[;<another raw folder>] <output folder> [--only=name,name]
// With --only just the named sounds are built (a name also stands for its numbered variants).
const fs = require('fs');
const path = require('path');
const wav = require('./wav_lib.js');

const [rawDirs, outDir] = process.argv.slice(2);
const only = (process.argv.find(a => a.startsWith('--only=')) || '').slice(7).split(',').filter(Boolean);
const files = [];
for (const dir of rawDirs.split(';')) {
  for (const f of fs.readdirSync(dir)) if (f.toLowerCase().endsWith('.wav')) files.push({ name: f, full: path.join(dir, f) });
}

// Raw files are named "<prompt start>_#<variant>-<timestamp>.wav".
function find(prefix, variant, stamp) {
  const hits = files.filter(f => f.name.startsWith(prefix) && f.name.includes(`_#${variant}-`) && (!stamp || f.name.includes(stamp)));
  if (hits.length === 0) throw new Error(`no raw file for ${prefix} #${variant}`);
  return hits.sort((a, b) => a.name < b.name ? -1 : 1)[0].full;
}

// One-pole filters are enough for gentle tone shaping; `poles` stacks them for a steeper slope.
function lowpass(x, rate, cutoff, poles = 2) {
  const a = Math.exp(-2 * Math.PI * cutoff / rate);
  let out = x;
  for (let p = 0; p < poles; p++) {
    const y = new Float32Array(out.length);
    let s = 0;
    for (let i = 0; i < out.length; i++) { s = (1 - a) * out[i] + a * s; y[i] = s; }
    out = y;
  }
  return out;
}
function highpass(x, rate, cutoff, poles = 1) {
  let out = x;
  for (let p = 0; p < poles; p++) {
    const low = lowpass(out, rate, cutoff, 1);
    const y = new Float32Array(out.length);
    for (let i = 0; i < out.length; i++) y[i] = out[i] - low[i];
    out = y;
  }
  return out;
}

// Loudest stretch of the sound, as RMS over a sliding window.
function loudness(x, rate, seconds = 0.2) {
  const win = Math.min(x.length, Math.floor(rate * seconds));
  let sum = 0;
  for (let i = 0; i < win; i++) sum += x[i] * x[i];
  let best = sum;
  for (let i = win; i < x.length; i++) {
    sum += x[i] * x[i] - x[i - win] * x[i - win];
    if (sum > best) best = sum;
  }
  return Math.sqrt(best / win);
}

// One layer of a mixed sound: mono, optionally filtered, peak at `gain`.
function component(part) {
  const src = wav.read(find(part.from, part.variant || 1, part.stamp));
  let x = wav.mono(src);
  if (part.lowpass) x = lowpass(x, src.rate, part.lowpass, 2);
  if (part.highpass) x = highpass(x, src.rate, part.highpass, 1);
  const peak = wav.peak(x);
  let first = 0;
  while (first < x.length && Math.abs(x[first]) < peak * 0.04) first++;
  const gain = (part.gain || 1) / Math.max(peak, 1e-6);
  const start = Math.max(0, first - Math.floor(src.rate * 0.001));
  return { rate: src.rate, samples: x.slice(start).map(v => v * gain) };
}

function build(spec) {
  let rate, channels;
  if (spec.mix) {
    // Layered sound: every part is lined up on its own first audible sample, then summed.
    const parts = spec.mix.map(component);
    rate = parts[0].rate;
    const sum = new Float32Array(Math.max(...parts.map(p => p.samples.length)));
    for (const part of parts) for (let i = 0; i < part.samples.length; i++) sum[i] += part.samples[i];
    channels = [sum];
  } else {
    const src = wav.read(find(spec.from, spec.variant || 1, spec.stamp));
    rate = src.rate;
    channels = spec.stereo ? src.channels.map(c => Float32Array.from(c)) : [wav.mono(src)];
  }
  if (spec.lowpass) channels = channels.map(c => lowpass(c, rate, spec.lowpass, 2));
  if (spec.highpass) channels = channels.map(c => highpass(c, rate, spec.highpass, 1));
  if (!spec.loop) {
    // Trim to the sound itself: start just before the first audible sample, stop when it has died away.
    const guide = channels.length === 1 ? channels[0] : channels[0].map((v, i) => (v + channels[1][i]) * 0.5);
    const peak = wav.peak(guide);
    let first = 0;
    const from = spec.skip ? Math.floor(spec.skip * rate) : 0;
    first = from;
    while (first < guide.length && Math.abs(guide[first]) < peak * (spec.gate || 0.04)) first++;
    first = Math.max(from, first - Math.floor(rate * 0.0015));
    let last = guide.length - 1;
    while (last > first && Math.abs(guide[last]) < peak * 0.006) last--;
    last = Math.min(guide.length, last + Math.floor(rate * 0.04));
    if (spec.length) last = Math.min(last, first + Math.floor(spec.length * rate));
    channels = channels.map(c => c.slice(first, last));
    const count = channels[0].length;
    const fadeIn = Math.floor(rate * 0.0008);
    const fadeOut = Math.min(count, Math.floor(rate * (spec.fade || 0.03)));
    // Optional extra decay tightens a boomy or ringing tail.
    const decay = spec.decay ? Math.log(1000) / (spec.decay * rate) : 0;
    const hold = Math.floor((spec.hold || 0.02) * rate);
    for (const c of channels) {
      for (let i = 0; i < fadeIn; i++) c[i] *= i / fadeIn;
      for (let i = 0; i < fadeOut; i++) c[count - 1 - i] *= i / fadeOut;
      if (decay) for (let i = hold; i < count; i++) c[i] *= Math.exp(-(i - hold) * decay);
    }
  } else {
    // Loops keep their full length; a short equal-power blend guarantees a seamless wrap.
    const blend = Math.floor(rate * 0.25);
    const count = channels[0].length - blend;
    channels = channels.map(c => {
      const out = c.slice(0, count);
      for (let i = 0; i < blend; i++) {
        const t = i / blend;
        out[i] = c[i] * Math.sin(t * Math.PI / 2) + c[count + i] * Math.cos(t * Math.PI / 2);
      }
      return out;
    });
  }
  // Optional saturation: presses the loud start and the quieter body closer together, so
  // the sound is denser at the same peak.
  if (spec.drive) {
    let top = 0;
    for (const c of channels) top = Math.max(top, wav.peak(c));
    const full = Math.tanh(spec.drive);
    channels = channels.map(c => c.map(v => Math.tanh(v / top * spec.drive) / full * top));
  }
  // Even loudness across the set, without ever clipping.
  const guide = channels.length === 1 ? channels[0] : channels[0].map((v, i) => (v + channels[1][i]) * 0.5);
  const level = loudness(guide, rate, spec.loop ? 1.0 : 0.2);
  let peak = 0;
  for (const c of channels) peak = Math.max(peak, wav.peak(c));
  const target = Math.pow(10, (spec.target === undefined ? -15 : spec.target) / 20);
  const gain = Math.min(target / Math.max(level, 1e-6), Math.pow(10, -1 / 20) / Math.max(peak, 1e-6));
  channels = channels.map(c => c.map(v => v * gain));
  const out = path.join(outDir, spec.name + '.wav');
  wav.write(out, { rate, channels });
  console.log(spec.name.padEnd(16), `${(channels[0].length / rate).toFixed(2)}s`, `${channels.length}ch`, `gain ${wav.db(gain).toFixed(1)}dB`, `peak ${wav.db(peak * gain).toFixed(1)}dB`, `loud ${wav.db(level * gain).toFixed(1)}dB`);
}

const SET = [
  // Weapons
  { name: 'shot', from: 'Gunshot,_M4_assault__', variant: 4, length: 0.5, fade: 0.08 },
  { name: 'p90', from: 'Gunshot,_MP5_submach_', variant: 4, length: 0.32, fade: 0.06 },
  { name: 'badger', from: 'Gunshot,_suppressed__', variant: 3, lowpass: 5200, highpass: 110, length: 0.3, decay: 0.22, hold: 0.012, fade: 0.05 },
  { name: 'click', from: 'Empty_gun_dry_fire_c_', length: 0.25 },
  { name: 'mag_out', from: 'Rifle_magazine_relea_', variant: 2, length: 0.3 },
  { name: 'mag_in', from: 'Rifle_magazine_inser_', variant: 1, length: 0.3 },
  { name: 'bolt', from: 'Rifle_charging_handl_', variant: 1, length: 0.4 },
  { name: 'equip', from: 'Rifle_handling_foley_', variant: 4, length: 0.55 },
  // Survivor
  { name: 'hurt', from: 'Short_male_grunt_of__', length: 0.6 },
  { name: 'step_wood_1', from: 'One_single_heavy_boo_', variant: 1, length: 0.35 },
  { name: 'step_wood_2', from: 'One_single_heavy_boo_', variant: 2, length: 0.35 },
  { name: 'step_grass_1', from: 'Single_footstep_on_w_', variant: 1, length: 0.4 },
  { name: 'step_grass_2', from: 'Single_footstep_on_w_', variant: 2, skip: 0.33, length: 0.4 },
  // Feedback and interface
  { name: 'hit', from: 'Bullet_hitting_flesh_', length: 0.3 },
  { name: 'headshot', from: 'Bullet_headshot_impa_', length: 0.4 },
  { name: 'pickup', from: 'Picking_up_a_metal_a_', length: 0.5 },
  { name: 'buy', from: 'Weapon_purchase_conf_', length: 0.6 },
  { name: 'radio', from: 'Military_walkie-talk_', length: 0.9, fade: 0.1 },
  { name: 'wave', from: 'Dark_horror_stinger,_', stereo: true, fade: 0.2 },
  { name: 'clear', from: 'Short_dark_military__', stereo: true, length: 1.2, fade: 0.25 },
  { name: 'shutter_open', from: 'Heavy_metal_roller_s_', stamp: '1791034009166', length: 1.5, fade: 0.1 },
  { name: 'shutter_close', from: 'Heavy_metal_roller_s_', stamp: '1791034035960', length: 1.5, fade: 0.1 },
  // The grenade launcher: the loud shot with the hollow thump of a quieter take under it.
  { name: 'launcher', mix: [
    { from: 'Grenade_launcher_fir_', variant: 1, gain: 1.0 },
    { from: 'Grenade_launcher_fir_', variant: 3, gain: 0.5, lowpass: 1400 }
  ], length: 0.9, fade: 0.3, drive: 1.8, target: -9.5 },
  // Hazards
  // A blast: a deep boom, cut down from a long roar to a hit that rolls away, with the
  // sharp crack of a shot on top. The raw booms hold their full level for over a second.
  { name: 'explosion_1', mix: [
    { from: 'Big_explosion_outdoo_', variant: 1, gain: 1.0 },
    { from: 'Grenade_launcher_fir_', variant: 4, gain: 1.3, highpass: 300 }
  ], length: 2.6, decay: 3.2, hold: 0.06, fade: 0.5, target: -10 },
  { name: 'explosion_2', mix: [
    { from: 'Big_explosion_outdoo_', variant: 2, gain: 1.0 },
    { from: 'Grenade_launcher_fir_', variant: 2, gain: 1.3, highpass: 300 }
  ], length: 2.6, decay: 3.2, hold: 0.06, fade: 0.5, target: -10 },
  { name: 'explosion_3', mix: [
    { from: 'Big_explosion_outdoo_', variant: 3, gain: 1.0 },
    { from: 'Grenade_launcher_fir_', variant: 4, gain: 0.55, highpass: 300 }
  ], length: 2.6, decay: 3.2, hold: 0.06, fade: 0.5, target: -10 },
  { name: 'explosion_4', mix: [
    { from: 'Big_explosion_outdoo_', variant: 4, gain: 1.0 },
    { from: 'Grenade_launcher_fir_', variant: 2, gain: 1.3, highpass: 300 }
  ], length: 2.6, decay: 3.2, hold: 0.06, fade: 0.5, target: -10 },
  { name: 'pop_1', from: 'Wet_fleshy_pop,_slim_', variant: 1, length: 0.45 },
  { name: 'pop_2', from: 'Wet_fleshy_pop,_slim_', variant: 4, length: 0.4 },
  { name: 'fuse', from: 'Flesh_swelling_and_s_', length: 1.9, fade: 0.1 },
  { name: 'squish', from: 'Fat_zombie_exploding_', length: 1.4, fade: 0.2 },
  { name: 'hiss', from: 'Acid_sizzling_and_hi_', length: 2.8, fade: 0.4 },
  // Infected
  { name: 'thud_1', from: 'Giant_monster_footst_', variant: 3, length: 0.7, fade: 0.15 },
  { name: 'thud_2', from: 'Giant_monster_footst_', variant: 2, length: 0.8, fade: 0.15 },
  { name: 'swipe', from: 'Fast_claw_swipe_whoo_', length: 0.65, fade: 0.08 },
  { name: 'growl_1', from: 'Aggressive_male_zomb_', variant: 1, fade: 0.1 },
  { name: 'growl_2', from: 'Aggressive_male_zomb_', variant: 2, fade: 0.1 },
  { name: 'growl_3', from: 'Aggressive_male_zomb_', variant: 3, fade: 0.1 },
  { name: 'growl_female_1', from: 'Rabid_female_zombie__', variant: 1, fade: 0.1 },
  { name: 'growl_female_2', from: 'Rabid_female_zombie__', variant: 2, fade: 0.1 },
  { name: 'pain_1', from: 'Zombie_grunting_in_p_', variant: 1, length: 0.7, fade: 0.08 },
  { name: 'pain_2', from: 'Zombie_grunting_in_p_', variant: 2, length: 0.7, fade: 0.08 },
  { name: 'death_1', from: 'Zombie_dying,_gurgli_', variant: 1, fade: 0.15 },
  { name: 'death_2', from: 'Zombie_dying,_gurgli_', variant: 2, fade: 0.15 },
  { name: 'gurgle', from: 'Bloated_fat_zombie_g_', fade: 0.1 },
  { name: 'screech_1', from: 'High-pitched_inhuman_', variant: 1, fade: 0.1 },
  { name: 'screech_2', from: 'High-pitched_inhuman_', variant: 2, fade: 0.1 },
  { name: 'roar_1', from: 'Giant_monster_roar,__', variant: 1, fade: 0.2 },
  { name: 'roar_2', from: 'Giant_monster_roar,__', variant: 2, fade: 0.2 },
  // Weather
  { name: 'thunder_1', from: 'Distant_thunder_clap_', variant: 1, stereo: true, gate: 0.02, fade: 0.6 },
  { name: 'thunder_2', from: 'Distant_thunder_clap_', variant: 2, stereo: true, gate: 0.02, fade: 0.6 },
  { name: 'wind', from: 'Cold_night_wind_blow_', stereo: true, loop: true, target: -20 },
  { name: 'rain', from: 'Steady_heavy_rain_fa_', stereo: true, loop: true, target: -20 },
  // Shotgun: a sharp crack layered over a deep boom
  { name: 'shotgun', mix: [
    { from: 'Shotgun_blast,_singl_', variant: 1, gain: 1.0 },
    { from: 'Gunshot,_Remington_8_', variant: 4, gain: 1.0, lowpass: 420 },
    { from: 'Gunshot,_Remington_8_', variant: 3, gain: 0.45 }
  ], length: 1.0, fade: 0.3, target: -11 },
  { name: 'shotgun_pump', from: 'Pump_action_shotgun__', variant: 1, length: 0.6 },
  { name: 'shell_in_1', from: 'Loading_one_shotgun__', variant: 2, gate: 0.3, length: 0.3 },
  { name: 'shell_in_2', from: 'Loading_one_shotgun__', variant: 3, gate: 0.3, length: 0.3 },
  { name: 'shell_in_3', from: 'Loading_one_shotgun__', variant: 4, gate: 0.3, length: 0.3 },
  // Teammates
  { name: 'bot_hurt_male_1', from: 'Male_soldier_short_p_', variant: 3, length: 0.8, fade: 0.08 },
  { name: 'bot_hurt_male_2', from: 'Male_soldier_short_p_', variant: 4, length: 0.8, fade: 0.08 },
  { name: 'bot_hurt_male_3', from: 'Male_soldier_short_p_', variant: 1, length: 0.8, fade: 0.08 },
  { name: 'bot_hurt_female_1', from: 'Female_soldier_short_', variant: 2, length: 0.8, fade: 0.08 },
  { name: 'bot_hurt_female_2', from: 'Female_soldier_short_', variant: 4, length: 0.8, fade: 0.08 },
  { name: 'bot_hurt_female_3', from: 'Female_soldier_short_', variant: 1, length: 0.8, fade: 0.08 },
  // Gore
  { name: 'gore_burst_1', from: 'Body_exploding_into__', variant: 4, fade: 0.3, target: -11 },
  { name: 'gore_burst_2', from: 'Body_exploding_into__', variant: 1, fade: 0.3, target: -11 },
  { name: 'gore_burst_3', from: 'Body_exploding_into__', variant: 3, fade: 0.3, target: -11 },
  { name: 'splat_1', from: 'Blood_splatter_hitti_', variant: 1, length: 0.5, fade: 0.1 },
  { name: 'splat_2', from: 'Blood_splatter_hitti_', variant: 3, length: 0.6, fade: 0.1 },
  { name: 'splat_3', from: 'Blood_splatter_hitti_', variant: 2, length: 0.5, fade: 0.1 },
  { name: 'gib_1', from: 'Chunks_of_meat_and_g_', variant: 2, length: 0.4, fade: 0.08 },
  { name: 'gib_2', from: 'Chunks_of_meat_and_g_', variant: 3, length: 0.42, fade: 0.08 },
  { name: 'gib_3', from: 'Chunks_of_meat_and_g_', variant: 1, length: 0.5, fade: 0.08 },
  { name: 'headpop_1', from: 'Head_exploding,_wet__', variant: 2, length: 0.55, fade: 0.1 },
  { name: 'headpop_2', from: 'Head_exploding,_wet__', variant: 4, length: 0.5, fade: 0.1 },
  { name: 'headpop_3', from: 'Head_exploding,_wet__', variant: 3, length: 0.5, fade: 0.1 },
  { name: 'bodyfall_1', from: 'Body_falling_on_wood_', variant: 1, length: 0.4, fade: 0.08 },
  { name: 'bodyfall_2', from: 'Body_falling_on_wood_', variant: 3, length: 0.35, fade: 0.08 },
  { name: 'bodyfall_3', from: 'Body_falling_on_wood_', variant: 4, length: 0.3, fade: 0.08 },
  // Ripper, the mutant hound
  { name: 'dog_growl_1', from: 'Vicious_mutant_dog_s_', variant: 1, fade: 0.2 },
  { name: 'dog_growl_2', from: 'Vicious_mutant_dog_s_', variant: 3, fade: 0.2 },
  { name: 'dog_growl_3', from: 'Vicious_mutant_dog_s_', variant: 4, fade: 0.2 },
  { name: 'dog_growl_4', from: 'Vicious_mutant_dog_s_', variant: 2, fade: 0.2 },
  { name: 'dog_bark_1', from: 'Monstrous_dog_attack_', variant: 2, length: 0.7, fade: 0.1 },
  { name: 'dog_bark_2', from: 'Monstrous_dog_attack_', variant: 3, length: 0.6, fade: 0.1 },
  { name: 'dog_bark_3', from: 'Monstrous_dog_attack_', variant: 4, length: 0.65, fade: 0.1 },
  { name: 'dog_bite_1', from: 'Monstrous_dog_bite,__', variant: 4, length: 0.6, fade: 0.1 },
  { name: 'dog_bite_2', from: 'Monstrous_dog_bite,__', variant: 3, length: 0.55, fade: 0.1 },
  { name: 'dog_bite_3', from: 'Monstrous_dog_bite,__', variant: 2, length: 0.55, fade: 0.1 },
  { name: 'dog_death_1', from: 'Large_monstrous_dog__', variant: 1, fade: 0.15 },
  { name: 'dog_death_2', from: 'Large_monstrous_dog__', variant: 3, fade: 0.15 },
  { name: 'dog_death_3', from: 'Large_monstrous_dog__', variant: 2, fade: 0.15 },
  { name: 'dog_howl_1', from: 'Demonic_hound_howlin_', variant: 1, fade: 0.3 },
  { name: 'dog_howl_2', from: 'Demonic_hound_howlin_', variant: 2, fade: 0.3 },
  { name: 'dog_howl_3', from: 'Demonic_hound_howlin_', variant: 3, fade: 0.3 },
  // More voices for the infected
  { name: 'striker_attack_1', from: 'Shrill_raspy_mutant__', variant: 1, fade: 0.1 },
  { name: 'striker_attack_2', from: 'Shrill_raspy_mutant__', variant: 2, fade: 0.1 },
  { name: 'striker_attack_3', from: 'Shrill_raspy_mutant__', variant: 3, fade: 0.1 },
  { name: 'striker_death_1', from: 'Screeching_mutant_cr_', variant: 1, fade: 0.15 },
  { name: 'striker_death_2', from: 'Screeching_mutant_cr_', variant: 2, fade: 0.15 },
  { name: 'striker_death_3', from: 'Screeching_mutant_cr_', variant: 3, fade: 0.15 },
  { name: 'striker_idle_1', from: 'Insect-like_creature_', variant: 3, fade: 0.2 },
  { name: 'striker_idle_2', from: 'Insect-like_creature_', variant: 4, fade: 0.2 },
  { name: 'striker_idle_3', from: 'Insect-like_creature_', variant: 1, fade: 0.2 },
  { name: 'charger_roar_1', from: 'Bloated_fat_zombie_w_', variant: 1, fade: 0.15 },
  { name: 'charger_roar_2', from: 'Bloated_fat_zombie_w_', variant: 2, fade: 0.15 },
  { name: 'charger_roar_3', from: 'Bloated_fat_zombie_w_', variant: 3, fade: 0.15 },
  { name: 'crusher_pain_1', from: 'Giant_monster_short__', variant: 3, length: 0.6, fade: 0.1 },
  { name: 'crusher_pain_2', from: 'Giant_monster_short__', variant: 2, length: 0.55, fade: 0.1 },
  { name: 'crusher_pain_3', from: 'Giant_monster_short__', variant: 4, length: 0.6, fade: 0.1 },
  { name: 'crusher_attack_1', from: 'Huge_monster_heavy_a_', variant: 1, length: 1.1, fade: 0.15 },
  { name: 'crusher_attack_2', from: 'Huge_monster_heavy_a_', variant: 2, length: 1.0, fade: 0.15 },
  { name: 'crusher_attack_3', from: 'Huge_monster_heavy_a_', variant: 3, length: 1.2, fade: 0.15 },
  { name: 'crusher_death_1', from: 'Colossal_monster_dyi_', variant: 1, fade: 0.3 },
  { name: 'crusher_death_2', from: 'Colossal_monster_dyi_', variant: 3, fade: 0.3 },
  { name: 'crusher_death_3', from: 'Colossal_monster_dyi_', variant: 4, fade: 0.3 },
  { name: 'attack_1', from: 'Angry_male_zombie_at_', variant: 1, fade: 0.12 },
  { name: 'attack_2', from: 'Angry_male_zombie_at_', variant: 2, fade: 0.12 },
  { name: 'attack_3', from: 'Angry_male_zombie_at_', variant: 3, fade: 0.12 },
  { name: 'attack_4', from: 'Angry_male_zombie_at_', variant: 4, fade: 0.12 },
  { name: 'moan_1', from: 'Male_zombie_low_rasp_', variant: 2, fade: 0.25 },
  { name: 'moan_2', from: 'Male_zombie_low_rasp_', variant: 3, fade: 0.25 },
  { name: 'moan_3', from: 'Male_zombie_low_rasp_', variant: 1, fade: 0.25 },
  { name: 'death_3', from: 'Male_zombie_death_ra_', variant: 3, fade: 0.2 },
  { name: 'death_4', from: 'Male_zombie_death_ra_', variant: 1, fade: 0.2 },
  { name: 'death_5', from: 'Male_zombie_death_ra_', variant: 2, fade: 0.2 },
  { name: 'death_female_1', from: 'Dying_female_zombie__', variant: 1, fade: 0.2 },
  { name: 'death_female_2', from: 'Dying_female_zombie__', variant: 2, fade: 0.2 },
  { name: 'death_female_3', from: 'Dying_female_zombie__', variant: 4, fade: 0.2 },
  { name: 'death_female_4', from: 'Dying_female_zombie__', variant: 3, fade: 0.2 },
  { name: 'pain_female_1', from: 'Female_zombie_short__', variant: 1, length: 0.85, fade: 0.1 },
  { name: 'pain_female_2', from: 'Female_zombie_short__', variant: 2, length: 0.85, fade: 0.1 },
  { name: 'pain_female_3', from: 'Female_zombie_short__', variant: 4, length: 0.85, fade: 0.1 }
];

fs.mkdirSync(outDir, { recursive: true });
const chosen = SET.filter(spec => only.length === 0 || only.some(name => spec.name === name || spec.name.startsWith(name + '_')));
for (const spec of chosen) build(spec);
console.log(chosen.length, 'sounds written to', outDir);
