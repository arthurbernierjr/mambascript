struct Status {
  str :: Number
  int :: Number
  dex :: Number
}

struct Battler {
  name   :: String
  lv     :: Number
  hp     :: Number
  wt     :: Number
  max_hp :: Number
  max_wt :: Number
  status :: Status

  group_id :: Number
}

struct BattleStage {
  players  :: Battler[]
  monsters :: Battler[]
}

_uid :: Number = 0
createGolbin :: Number -> Battler = (lv :: Number, group_id :: Number) ->
  name: "Goblin"
  uid: _uid++
  group_id: group_id
  lv: lv
  hp: 30
  max_hp: 30
  wt: 0
  max_wt: 20
  status:
    str: 5 + lv
    int: 2 + ~~(lv/3)
    dex: 2 + ~~(lv/2)

charge_or_attack = (stage :: BattleStage, actor :: Battler) ->
  if actor.wt < actor.max_wt then actor.wt++; return

  targets = ([].concat stage.players, stage.monsters).filter (b :: Battler) ->
    b.group_id isnt actor.group_id and b.hp > 0
  target = targets[~~(Math.random() * targets.length)]
  console.log "#{actor.name}(#{actor.uid}) HP: #{actor.hp} の攻撃 > #{target.name}(#{target.uid})"
  target.hp -= actor.status.str
  if target.hp <= 0 then console.log "#{target.name}(#{target.uid})は死んだ"
  actor.wt = 0

is_defeated = (battlers :: Battler[]) :: Boolean ->
  for battler :: Battler in battlers when battler.hp > 0
    return false
  true

step_turn = (stage :: BattleStage) -> 
  for battler :: Battler in [].concat stage.players, stage.monsters when battler.hp > 0
    charge_or_attack stage, battler

stage :: BattleStage =
  players : (createGolbin(2, 0) for i in [1..3])
  monsters: (createGolbin(2, 1) for i in [1..3])

for i in [1..200]
  step_turn stage
  if is_defeated stage.players  then console.log 'playerは負けました'; break
  if is_defeated stage.monsters then console.log 'monsterは負けました'; break
console.log "#{battler.name}(#{battler.uid}: #{battler.hp}" for battler in [].concat stage.players, stage.monsters


