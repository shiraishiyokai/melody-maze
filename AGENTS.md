# AGENTS.md — 旋律迷宫 (Melody Maze) 项目说明文档

> 本文档面向 AI 助手，用于在对话上下文丢失后快速恢复对项目的完整理解。
> 最后更新：2026-06-08

---

## 1. 项目概览

**旋律迷宫 (Melody Maze)** 是一款基于 Godot 4.6 的肉鸽卡牌构筑游戏（Roguelike Deckbuilder），主题为音乐/音游，中文界面。玩家选择角色后，在 20 层分支地图中逐层推进，通过卡牌战斗、商店购卡、篝火升级等方式构建卡组，最终击败唯一 Boss。

- **引擎**: Godot 4.6, GDScript
- **分辨率**: 1280×720, Canvas Items 拉伸模式
- **渲染器**: GL Compatibility
- **UI 构建方式**: 全部代码构建（无 .tscn UI 节点），所有场景的 `_build_ui()` 方法程序化创建界面
- **语言**: 中文（代码注释英文+中文混合，用户界面全中文）

---

## 2. 项目结构

```
melody_maze/
├── project.godot              # 项目配置，定义 4 个 Autoload 单例
├── data/
│   ├── cards.json             # 卡牌数据（80张：8基础+10通用+62角色专属）
│   ├── enemies.json           # 敌人数据（25个：15普通+6精英+4Boss）
│   └── relics.json            # 遗物数据（28个：12普通+12稀有+4传说）
├── assets/
│   ├── bg/                    # 背景装饰 SVG
│   ├── cards/                 # 卡牌图片 PNG
│   ├── enemies/               # 敌人精灵 SVG
│   ├── icons/                 # 属性图标 PNG
│   ├── player/                # 角色图标 PNG（FF14 职业图标）
│   ├── fonts/                 # （空）
│   └── ui/                    # （空）
├── scenes/
│   ├── main.tscn              # 入口场景 → 跳转主菜单
│   ├── main_menu.tscn         # 角色选择界面
│   ├── battle.tscn            # 战斗场景
│   ├── map.tscn               # 地图导航界面
│   ├── shop.tscn              # 商店界面
│   ├── campfire.tscn          # 篝火休息界面
│   ├── reward.tscn            # 战斗胜利奖励界面
│   └── relic_pick.tscn        # 遗物选择界面（精英/Boss 胜利后）
├── scripts/
│   ├── game_manager.gd        # [Autoload] 全局状态管理器
│   ├── card_database.gd       # [Autoload] 卡牌数据库
│   ├── enemy_database.gd      # [Autoload] 敌人数据库
│   ├── relic_database.gd      # [Autoload] 遗物数据库
│   ├── card_data.gd           # CardData 资源类
│   ├── enemy_data.gd          # EnemyData 资源类
│   ├── relic_data.gd          # RelicData 资源类
│   ├── battle_manager.gd      # 战斗逻辑控制器
│   ├── battle_scene.gd        # 战斗 UI 控制器
│   ├── card_node.gd           # 卡牌 UI 组件（拖拽出牌+数值显示）
│   ├── enemy_node.gd          # 敌人 UI 组件
│   ├── deck_viewer.gd         # 牌库查看工具
│   ├── main.gd                # 入口脚本
│   ├── main_menu.gd           # 角色选择 UI
│   ├── map_scene.gd           # 地图导航 UI
│   ├── map_generator.gd       # 地图生成算法
│   ├── shop_scene.gd          # 商店 UI
│   ├── campfire_scene.gd      # 篝火 UI
│   ├── reward_scene.gd        # 奖励 UI
│   └── relic_pick_scene.gd    # 遗物选择 UI
```

---

## 3. Autoload 单例

### 3.1 GameManager（全局状态管理器）

**路径**: `scripts/game_manager.gd`

核心变量与职责：

| 变量 | 类型 | 说明 |
|------|------|------|
| `player_hp` / `player_max_hp` | int | 玩家生命值，初始 80/80 |
| `gold` | int | 金币 |
| `current_floor` / `max_floors` | int | 当前层 / 总层数(20) |
| `energy` / `max_energy` | int | 当前/最大能量，初始 3/3 |
| `player_block` | int | 当前护盾值，回合开始重置为 0 |
| `deck` / `draw_pile` / `hand` / `discard_pile` | Array[CardData] | 牌组/抽牌堆/手牌/弃牌堆 |
| `last_played_attribute` | int | 上张打出牌的属性枚举值，-1=无；和声触发后重置为-1 |
| `last_played_card_type` | int | 上张打出牌的类型枚举值，-1=无 |
| `harmony_count` | int | 本战斗和声累计触发次数（不重置，跨回合累计） |
| `kills_this_battle` | int | 本局击杀敌人数 |
| `strength_buff` | int | 力量 buff（每攻击+N伤害），战斗结束重置 |
| `dexterity_buff` | int | 敏捷 buff（每防御+N护盾），战斗结束重置 |
| `vulnerable_stacks` | int | 易伤层数（受攻击+50%，每回合-1） |
| `power_harmony_mult` | bool | 能力牌：和声倍率 1.4→1.6（升级→1.8） |
| `power_skill_str` | bool | 能力牌：每打出技能牌+1力量 |
| `power_skill_dex` | bool | 能力牌升级：每打出技能牌+1敏捷 |
| `power_first_return` | bool | 能力牌：每回合首牌回手 |
| `power_extra_energy` | bool | 能力牌：每回合+1能量 |
| `power_extra_gold` | int | 能力牌升级：每回合额外获得N金币 |
| `power_harmony_draw_count` | int | 能力牌：和声触发时抽N牌（1默认，升级2） |
| `power_beat_energy` | bool | 能力牌：上回合N+牌→+1能量 |
| `power_beat_threshold` | int | 节拍能量门槛，默认3（升级→2） |
| `power_play_energy` | bool | 類·指挥之心：每回合N+牌→下回合+1能量 |
| `power_play_threshold` | int | 指挥之心门槛，默认3（升级→2） |
| `harmony_boost_active` | bool | 下次和声效果翻倍（一次性） |
| `next_card_discount` | int | 類·彩排：下张牌费用减免量（2/3），打出下张牌后归零 |
| `first_attack_played_this_turn` | bool | 本回合是否已打出攻击牌（遗物 pitch_pipe 判定） |
| `first_defense_played_this_turn` | bool | 本回合是否已打出防御牌（遗物 music_stand 判定） |
| `cards_played_this_turn` | int | 本回合已打出卡牌数（节拍计数器） |
| `prev_turn_cards_played` | int | 上回合打出的卡牌数 |
| `relics` | Array[String] | 遗物ID列表 |
| `relic_pick_pending` / `relic_pick_count` | bool/int | 遗物选择待处理状态 |
| `selected_character_id` | int | 当前角色ID |
| `in_battle` / `run_active` | bool | 战斗/冒险进行中 |

**重要：`first_attack_played_this_turn`/`first_defense_played_this_turn` 标记在 `battle_manager.play_card_effects()` 末尾设置（在所有遗物检查之后），而非在 `GameManager.play_card()` 中设置。**

关键信号：`hp_changed`, `gold_changed`, `block_changed`, `energy_changed`, `battle_started`, `battle_won`, `battle_lost`, `turn_started`, `turn_ended`, `run_complete`

关键方法：
- `start_new_run(character_id)`: 初始化新冒险
- `start_battle(enemies)`: 洗牌、抽5张（含 guaranteed_first_draw 卡牌优先入手）、重置战斗状态
- `play_card(card) → bool`: 扣能量（使用 `card.get_display_cost()` 含升级费用/next_card_discount/wah_pedal/headphone 减费）、处理和声判定、处理消耗/能力牌
- `end_player_turn()`: 手牌→弃牌堆、重置追踪
- `start_new_turn()`: 回复能量、重置护盾、抽牌、检查遗物/能力加成（含 power_beat_energy/power_play_energy 使用 threshold 变量、power_extra_gold）
- `take_damage(amount)`: 先扣护盾再扣血

### 3.2 CardDB（卡牌数据库）

**路径**: `scripts/card_database.gd`

- `_ready()` 时从 `data/cards.json` 加载所有卡牌到 `_cards: Dictionary`（id → CardData）
- `get_card(id)`, `get_all_cards()`, `get_cards_by_rarity()`, `get_cards_by_character()`, `get_cards_by_attribute()`
- `get_shop_cards(count)`: 仅返回当前角色的卡牌
- `get_random_reward_cards(count)`: 仅返回当前角色的卡牌
- `get_starting_deck(character_id)`: 4×旋律斩 + 4×旋律盾 + 2张角色专属初始牌
- **默认升级值**：`upgraded_damage = damage + 3 if damage > 0 else 0`（block 同理）。这意味着 base=0 的属性升级后不会凭空获得+3，必须显式设置

### 3.3 EnemyDB（敌人数据库）

**路径**: `scripts/enemy_database.gd`

- 从 `data/enemies.json` 加载，`get_enemy(id)`, `get_enemies_by_tier()`
- `get_boss_for_floor(floor)`: 仅20F=虚无调律师
- `get_random_normal_by_layer(layer)` / `get_random_elite_by_layer(layer)`: 按 layer 筛选

### 3.4 RelicDB（遗物数据库）

**路径**: `scripts/relic_database.gd`

- 从 `data/relics.json` 加载，`_relics: Dictionary`（id → RelicData）
- `get_relic(id)`, `get_random_relic_choices(count, encounter_type)`: 按稀有度权重随机选取，排除已拥有和 boss_only（非 Boss）
- `get_shop_relics(count)`: 排除 boss_only 和已拥有的遗物
- 精英权重: COMMON:50/RARE:35/LEGENDARY:15；Boss权重: COMMON:30/RARE:40/LEGENDARY:30

---

## 4. 数据类

### 4.1 CardData

`scripts/card_data.gd`, `class_name CardData extends Resource`

```gdscript
enum CardType { ATTACK, DEFENSE, SKILL, POWER }
enum Attribute { NONE, CUTE, COOL, HAPPY, MYSTERIOUS, PURE }
enum Rarity { COMMON, RARE, LEGENDARY }
```

导出变量：`id, card_name, character_name, cost, card_type, attribute, rarity, damage, block, effect_text, effect_id, image_path, upgraded_cost, upgraded_damage, upgraded_block, upgraded_effect_text, is_upgraded, guaranteed_first_draw, character_id`

辅助方法：
- `get_display_cost() → int`: 升级后若 `upgraded_cost >= 0` 返回升级费用，否则返回 base cost
- `get_display_damage/block/text()`: 根据是否升级返回对应值
- `is_harmony_card()`: effect_id 以 harmony_ 开头 或 为 always_harmony / block_if_harmony_3 / block_harmony_double / power_harmony_mult / power_harmony_draw / harmony_combo_5
- `is_exhaust()`: effect_id 以 exhaust 开头 或 effect_text 包含"消耗"

**新字段说明**：
- `upgraded_cost: int = -1`：-1 表示与 base 相同。设为 0 时升级后费用变0（用于 mizuki_power）
- `guaranteed_first_draw: bool = false`：为 true 时，战斗开始必定在初始手牌中

character_id：0=基础, 1=一歌, 2=杏, 13=司, 14=えむ, 16=類, 17=奏, 20=瑞希

### 4.2 EnemyData

`scripts/enemy_data.gd`, `class_name EnemyData extends Resource`

```gdscript
enum IntentType { ATTACK, DEFEND, BUFF, DEBUFF, EMPOWER }
enum EnemyTier { NORMAL, ELITE, BOSS }
```

导出变量：`id, enemy_name, tier, layer, min_hp, max_hp, image_path, moves`

### 4.3 RelicData

`scripts/relic_data.gd`, `class_name RelicData extends Resource`

```gdscript
enum Rarity { COMMON, RARE, LEGENDARY }
```

导出变量：`id, name, description, rarity, price, boss_only`
辅助方法：`get_rarity_name()`, `get_rarity_color()`

---

## 5. 核心系统

### 5.1 和声 (Harmony) 系统

和声是游戏核心机制，但各角色对和声的依赖程度不同：

1. **触发条件**：连续打出两张**相同属性**的牌时，第二张触发和声
2. **触发后重置**：`last_played_attribute = -1`，需再打出两张同属性牌才能再次触发
3. **基础效果**：伤害/护盾 ×1.4；若有 power_harmony_mult → ×1.8（升级）或 ×1.6（resonance_fork 遗物）
4. **属性加成**（和声触发时额外获得，harmony_boost_active 时翻倍）：
   - CUTE → 回复 1 HP（翻倍=2）
   - COOL → 敌人 -1 力量（翻倍=2）
   - HAPPY → 抽 1 牌（翻倍=2）
   - MYSTERIOUS → 敌人 +1 易伤（翻倍=2）
   - PURE → +1 护盾（翻倍=2）
5. **NONE 属性牌**不参与和声，打出后重置 `last_played_attribute = -1`
6. **单属性角色**（類=happy、杏=cool等）打出任何两张牌即触发和声，触发频繁但已重置机制平衡
7. **延迟触发**：和声属性效果（如 MYSTERIOUS 易伤）在伤害/护盾计算**之后**触发，避免触发卡自身享受自己的易伤加成

### 5.2 卡牌效果系统 (effect_id)

效果分三类处理，**每类都有 skip list** 将已在其他类中处理过的 effect_id 跳过：

**技能效果** (`_process_skill_effect`):

| effect_id | 说明 | 升级效果 |
|-----------|------|---------|
| `draw_2` / `draw_1` | 抽牌 | 抽3/2 |
| `draw_2_skill_power` | 抽2/3牌，手牌每技能+1力量 | 抽3 |
| `draw_2_skill_discount` | 抽2牌，手牌技能牌费用-1/2 | -2 |
| `exhaust_draw_2` | 抽2牌，消耗自身 | — |
| `dodge` | 获得护盾 | — |
| `trade` | 获得15/25金，消耗自身 | 25金 |
| `gold_20_block_5` | 获得20金+5护盾 | — |
| `power_up` | +2力量 | — |
| `harmony_boost` | 下次和声效果翻倍 | — |
| `heal_low_hp` | HP<50%回6/8，否则回3/5 | 回复量增加 |
| `purify` | 清除负面buff | 额外回复3HP |
| `cycle_draw3_discard2` | 抽3弃2 | — |
| `retrieve_attack` | 从弃牌堆拿回1/2张攻击牌 | 2张 |
| `next_card_discount` | 類·彩排：下牌-2/3费 | -3 |
| `ichika_alternate` | 一歌·弦乐交替：3/5伤+3/5盾 | 5/5 |
| `cycle_discard_power` | 奏·灵感碎片 | 门槛5→4，+1→+2力 |
| `draw_1_echo_play` | 瑞希·影分身 | 抽1→2 |
| `str_2_minus_1_energy` | 司·蓄力姿态：+2/3力-1能 | +3力 |
| `discard_damage_all_draw3` | 奏·终章·无眠 | 除数3→2 |
| `beat_strength_per_card` | 杏·踏拍：每之前牌+1力 | 额外抽1 |
| `damage_gain_gold_5` | えむ·金币弹：5/8伤+5/8金 | 伤8+金8 |
| `exhaust_retrieve_2` | 奏·废墟回收：取2/3张牌 | 3张 |
| `draw_2_discard_1` | 瑞希·回旋音符：抽2/3弃1 | 抽3 |

**能力效果** (`_process_power_effect`)：

| effect_id | 说明 | 升级效果 |
|-----------|------|---------|
| `power_str_1` | +1力量(永久) | — |
| `power_str_2` | +2力量(永久) | 额外+1敏捷 |
| `power_dex_1` | +1敏捷(永久) | — |
| `power_harmony_mult` | 和声倍率×1.6 | ×1.8 |
| `power_skill_str` | 每技能牌+1力量 | 额外+1敏捷/技能 |
| `power_first_return` | 首牌回手 | 费用1→0 |
| `power_extra_energy` | 每回合+1能量 | 额外+3金/回合 |
| `power_harmony_draw` | 和声抽1/2牌 | 抽2 |
| `power_beat_energy` | 上回合3+牌→+1能量 | 门槛3→2 |
| `power_play_energy` | 類·指挥之心 | 门槛3→2 |

**通用卡牌效果** (`_process_card_effect`):

| effect_id | 说明 | 升级效果 |
|-----------|------|---------|
| `aoe_3` / `aoe_5_str` | 全体伤害 | — |
| `gain_strength_1/2` | +1/2力量 | +2/+3 |
| `combo_2` | 攻击2次 | — |
| `pierce` / `pierce_weak` | 穿透护盾 | — |
| `harmony_combo_4` | 一歌·和声+4/7伤害 | +7 |
| `harmony_combo_5` | 一歌·回音斩：和声+5/8伤害 | +8 |
| `finale_harmony_scaling` | 類·终章·交响：基础+(和声×5)伤害 | — |
| `combo_if_2_cards_6` | 類·复奏冲击：2+牌时再+6/8伤害 | +8 |
| `first_attack_vulnerable_2` | 類·出场：首攻+2易伤 | — |
| `block_if_intent_attack` | 類·指挥盾：敌攻意图+3/4护盾 | +4 |
| `first_card_damage_4` | 杏·首拍斩：第1张牌+4/6伤害 | +6 |
| `per_card_damage_2` | 杏·律动连打：每之前牌+2/3伤害 | +3 |
| `strength_double` | 司·霸气斩：力量双倍计入伤害 | — |
| `discard_bonus_3` | 奏·冷冽斩：弃牌堆5+时+3/5伤害 | +5 |
| `hand_bonus_damage_2` | 瑞希·幻影连击：手牌每张+2/3伤害 | +3 |
| `gold_per_block_2` | えむ·富足之盾：每30金+2/3护盾 | +3 |
| `finale_cost_reduce` | 一歌·终章：3+和声→费用-2 | — |
| `gold_bonus_damage_3` | えむ·金≥50→+3/5伤害 | +5 |
| `gold_scaling_damage_exhaust` | えむ·每30金+5伤害 | — |
| `hand_scale_block_2` | 瑞希·手牌每少1张+2/3护盾 | +3 |
| `kill_scaling_exhaust` | 司·每击杀+15/20伤害 | +20 |
| `beat_*` | 杏·节拍系列 | — |

### 5.3 节拍 (Beat) 机制（杏专属）

- `cards_played_this_turn` 追踪每回合打出卡牌数
- 第1拍=首牌加成, 第2拍=+护盾, 第3拍=+伤害/穿透+易伤
- 终章·狂想 = (出牌数-1) × 6/8 额外伤害

### 5.4 遗物系统

28个遗物，3稀有度 + boss_only标记：

**COMMON（12个）**：消音器(受伤-1)、节拍器(前2回合+1抽)、合唱踏板(和声+2盾)、鼓槌(击杀回3HP)、黑胶唱片(首回合+4盾)、磁带(首次和声+1抽)、声卡(商店8折)、音笛(首攻+2伤)、谱架(首防+2盾)、调律钥匙(篝火+5HP)、喇叭(手牌≤3攻+2)、和声铃(第2次和声回2HP)

**RARE（12个）**：调律叉(+1能/-1抽,Boss限定)、收音机(+1抽)、共振叉(和声×1.6)、失真踏板(+3攻/-1HP/回合)、混响板(+3盾/-1HP/回合)、回音室(和声+1力量)、耳机(首牌-1费)、哇音踏板(每3牌下牌0费)、延音踏板(弃堆≥8攻+4)、麦克风(技能抽+1)、低音炮(AOE+3)、暗室(敌攻意图-3伤)

**LEGENDARY（4个）**：隔音头罩(30%伤害减半)、扩音器(伤+金/50)、三角钢琴(每3遗物+1能,Boss限定)、终章乐谱(终章卡+50%伤)

**获取途径**：精英→3选1(排除boss_only)，Boss→3选1(含boss_only)，普通→10%概率1个(仅common)，商店→2个可购

### 5.5 战斗流程

1. `BattleManager.setup(enemy_data)`: 初始化敌人HP、选择首个意图
2. `GameManager.start_battle()`: 洗牌、guaranteed_first_draw 卡牌优先入手、抽5张、重置战斗状态
3. 玩家回合：出牌 → `GameManager.play_card()` → `BattleManager.play_card_effects()`
4. 结束回合 → 敌人回合 → 新回合开始
5. 战斗胜利 → 精英/Boss: relic_pick → reward；普通: 10% relic_pick → reward
6. 战斗失败 → 主菜单

**卡牌数值显示**：`card_node.gd` 的 `_update_display()` 计算并显示包含所有加成的实际伤害/护盾值（力量、遗物加成等），格式如 `ATK:15(+3遗/+2首攻)`。使用 `card_data.get_display_damage()/get_display_block()` 获取升级后基础值。

### 5.6 地图生成

- 20层分支地图，1-3条并行路径
- **固定结构**：1F起点→5F精英→10F篝火→15F精英→19F篝火→20F Boss
- 2车道层(2,6,11,16)：15%商店/85%战斗
- 2车道汇合层(4,9,14,18)：20%商店/80%篝火
- 3车道层：55%战斗/14%事件/13%商店/12%篝火/10%精英
- 四层敌人区：Layer 1(1-5F), Layer 2(6-10F), Layer 3(11-15F), Layer 4(16-20F)

---

## 6. 角色系统

| ID | 名称 | 属性 | 机制关键词 | 卡牌数 | 初始牌 |
|----|------|------|-----------|--------|--------|
| 1 | 星乃一歌 | mysterious | 和声倍率放大 | 10 | 弦音斩+守盾旋律 |
| 17 | 宵崎奏 | cool | 弃牌堆操控 | 11 | 混沌旋律+深夜作曲 |
| 2 | 白石杏 | happy | 节拍连击（出牌位置联动） | 10 | 节拍斩+律动盾 |
| 20 | 暁山瑞希 | happy | 手牌操控/回手 | 10 | 闪避旋律+幻影斩 |
| 16 | 神代類 | happy | **多面指挥**（攻防混合+时机加成） | 10 | 奇想斩+彩排 |
| 14 | 鳳えむ | cute | 金币联动 | 10 | 交易旋律+欢笑盾 |
| 13 | 天馬司 | pure | 力量堆积 | 10 | 爆裂旋律+舞台斩 |

---

## 7. 敌人系统

25个敌人按4层分布：

**Layer 1(1-5F)**: 噪音史莱姆、失调蝙蝠、回响幽灵、走音机器人 | 精英：混音巨兽、和弦守护者
**Layer 2(6-10F)**: 混乱乐师、低频蠕虫、旋律蛇、失真镜像 | 精英：节奏恶魔、回旋交响
**Layer 3(11-15F)**: 虚空回声、断裂调弦、静音刺客 | 精英：共振暴君、终末合唱
**Layer 4(16-20F)**: 不协和幽灵、混沌指挥家、静电恐魔 | 精英：噪音之王、静默之主
**Boss(20F)**: 虚无调律师

---

## 8. 场景流转

```
main.tscn → main_menu.tscn (选角色)
                    ↓
              map.tscn (地图导航)
               ↙ ↓ ↓ ↘
    battle.tscn  shop.tscn  campfire.tscn
         ↓ ↓
    relic_pick.tscn (精英/Boss/10%概率)
         ↓
    reward.tscn → map.tscn
```

---

## 9. UI 架构

### 战斗场景 (battle_scene.gd)

最复杂场景，程序化构建全部 UI：

- **布局**：左=玩家区(图标+HP+buff)、右=敌人区、底=手牌区+按钮
- **遗物栏**：左上角(y=38)，悬停显示详情面板（自定义 mouse_entered/mouse_exited）
- **卡牌数值**：显示计算后的实际值（含力量/遗物加成），如 `ATK:15(+3遗/+2首攻)`
- **卡牌详情面板**：悬停显示计算后攻击/护盾值+实际费用
- **帮助面板**：和声机制说明（含"触发后重置"和属性数值）
- **弹窗管理**：`_close_all_popups()` 关闭所有弹窗

### 卡牌显示 (card_node.gd)

- `_update_display()` 计算并显示所有加成后的实际伤害/护盾
- 使用 `card_data.get_display_damage()/get_display_block()` 获取升级后基础值
- 可见性判断：`card_data.get_display_damage() > 0 or card_data.damage > 0`（兼容升级后新增属性）
- 加成来源：力量、遗物(distortion_pedal/pitch_pipe/speaker_cone/amplifier/sustain_pedal)、敏捷、遗物(reverb_plate/music_stand)
- 费用显示：使用 `card_data.get_display_cost()` + 遗物减免(wah_pedal/headphone)后的实际费用
- 拖拽出牌：攻击牌需拖到敌人区域，其他牌拖拽释放即可

### 篝火升级 (campfire_scene.gd)

- 升级预览格式：`"卡名 X费: 当前效果文本 → 升级后效果文本"`
- 不再显示 "ATK:X DEF:X" 格式，改为效果文本对比
- 费用变化也会显示：`" → 0费: 升级效果"`

---

## 10. 数据格式

### cards.json

```json
{
  "id": "rui_strike",
  "card_name": "奇想斩",
  "character_name": "神代類",
  "cost": 1, "card_type": "attack", "attribute": "happy",
  "rarity": "common", "damage": 6, "block": 3,
  "effect_text": "造成6伤害，获得3护盾",
  "effect_id": "",
  "image_path": "...",
  "upgraded_damage": 9, "upgraded_block": 5,
  "upgraded_effect_text": "造成9伤害，获得5护盾",
  "upgraded_cost": -1,
  "guaranteed_first_draw": false,
  "character_id": 16
}
```

**升级字段完整规则**：
- `upgraded_damage`：不写时默认 `damage + 3 if damage > 0 else 0`（0属性不会凭空+3）
- `upgraded_block`：同上，默认 `block + 3 if block > 0 else 0`
- `upgraded_effect_text`：不写时默认与 `effect_text` 相同（**但必须显式写**，因为效果文本中的数值不会自动更新）
- `upgraded_cost`：不写时默认 -1（表示与 base 相同）。设为 0 时升级后费用变0
- `guaranteed_first_draw`：不写时默认 false。为 true 时战斗开始必在初始手牌

不支持注释，必须是纯合法 JSON。攻击牌的 `block>0` 会触发"攻击牌也加护盾"的二级效果逻辑（battle_manager lines ~176-183）。

### relics.json

```json
{
  "id": "tuning_fork",
  "name": "调律叉",
  "description": "每回合+1能量，但每回合少抽1牌",
  "rarity": "rare",
  "price": 250,
  "boss_only": true
}
```

### enemies.json

```json
{
  "id": "noise_slime",
  "enemy_name": "噪音史莱姆",
  "tier": "normal", "layer": 1,
  "min_hp": 28, "max_hp": 35,
  "image_path": "...",
  "moves": [{"intent": "attack", "value": 9, "weight": 3}]
}
```

---

## 11. 新增内容操作步骤

### 新增卡牌
1. `data/cards.json` 添加条目（**必须写 `upgraded_effect_text`**）
2. `battle_manager.gd` 实现 effect_id（技能→`_process_skill_effect`，能力→`_process_power_effect`，其他→`_process_card_effect`）
3. 如 effect_id 在 skill/power 中处理→添加到 `_process_card_effect` 的 skip list（用 `\` 续行）
4. 如需消耗→`CardData.is_exhaust()` 添加匹配
5. 如与和声交互→`CardData.is_harmony_card()` 添加匹配
6. 如需新追踪变量→`GameManager` 添加并在 `start_battle()`/`start_new_turn()` 中重置
7. 如在ATTACK主分支中处理→注意在遗物检查之后设置 `first_attack_played_this_turn`
8. 如需费用升级→设置 `upgraded_cost` 字段，确保 `get_display_cost()` 正确返回

### 新增遗物
1. `data/relics.json` 添加条目
2. `game_manager.gd` 添加遗物效果检查逻辑
3. `battle_manager.gd` 添加遗物对伤害/护盾/抽牌的影响
4. 如为 boss_only→仅在 Boss 奖励池出现

---

## 12. 已知问题与约束

1. **UI 全部代码构建**：修改 UI 需在 `_build_ui()` 中调整代码
2. **单敌人战斗**：仅支持 1v1
3. **Tab/空格混合**：部分文件混用，用 Edit 工具时需用 `python3` 确认实际缩进
4. **卡牌 name_label 显示 character_name**：这是已知设计

---

## 13. 效率教训

| 场景 | 高效做法 |
|------|---------|
| 定位数值 bug | 先验证数值（看日志），再决定追踪方向 |
| 搜索跨文件引用 | 一次性 `grep -rn` 全项目搜索 |
| 编辑 GDScript | 用 Python 脚本读写文件，避免 shell 工具缩进陷阱 |
| 判断问题层级 | 先排除 UI/显示层问题 |
| 修改 match 块 | 先用 `sed -n` + `cat -e` 确认实际缩进（tab数量），再精确替换 |
| 添加新分支 | 在 match 块中插入新 case 时，确保与相邻 case 缩进一致（通常2tab） |

---

## 14. GDScript 编码易错点 ⚠️⚠️⚠️

> **🔴 缩进错误是本项目最高频的致命bug，已导致至少6次解析失败（card_data.gd 2次 + battle_manager.gd 2次 + game_manager.gd 1次 + 续行符1次）。每次都是工具写入了错误的tab数量。以下规则必须严格遵守，不得跳过任何步骤。**

### 14.0 强制操作流程（修改 GDScript 的唯一正确方式）

> ⚠️ **以下流程是强制性的，不是建议。跳过任何步骤 = 必定出bug。**

```
步骤1【前置】：先读目标文件相邻行，用 python3 打印 tab 数
  python3 -c "
  with open('file.gd') as f:
      lines = f.readlines()
  for i in range(X-1, Y):
      tabs = 0
      while tabs < len(lines[i]) and lines[i][tabs] == '\t': tabs += 1
      print(f'L{i+1}: tabs={tabs} | {lines[i].rstrip()[:70]}')
  "

步骤2【查表】：根据下方14.1的缩进对照表，确定要插入的每行应该有多少tab

步骤3【编写】：Python脚本中，用 \t 写入正确数量的tab（见14.2示例）

步骤4【验证】：写入后立即再次执行步骤1，确认每行的tab数与对照表一致

步骤5【字节检查】：如果代码包含续行符 \ ，必须检查原始字节（见14.3）
```

**🔴 禁止事项**：
- ❌ 禁止不执行步骤1就直接写代码
- ❌ 禁止凭"记忆"或"感觉"确定tab数——必须查表+实测
- ❌ 禁止写完代码后跳过验证步骤
- ❌ 禁止使用 Edit 工具修改多行 GDScript 代码（tab匹配必出错，用Python脚本替代）
- ❌ **🔴 禁止使用 Edit 工具在 GDScript 中插入行/替换行**（见 bug #6 详解）

**🔴 Bug #6 详解——Edit 工具的 new_string 中 `\n` + `\t` 组合陷阱**：

用 Edit 在 `var next_card_discount` 前插入新行时，`new_string` 写成：
```
var headphone_used: bool = false  # 耳机遗物：每回合已用过折扣
	var next_card_discount: int = 0  # 類·彩排: 下张牌费用减免量（用完归零）
```

看起来正确——`next_card_discount` 行有1个tab。但 Edit 的 `old_string` 是 `var next_card_discount`（0tab），`new_string` 中包含 `\n`（换行）+ `\t`（tab）。**Edit 在替换时会保留 `old_string` 末尾已有的 `\n`，导致实际写入的文件变成**：

```
var headphone_used: bool = false\n    \tvar next_card_discount: int = 0
```

`headphone_used` 行的 `\n` 结尾 + `new_string` 第二行的 `\t` 前缀 = **多了一个 `\n`，让下一行多出1个tab**。最终 `next_card_discount` 变成1tab（应为0tab），GDScript 解析报 "Unexpected Indent in class body"。

**教训**：Edit 工具的 `new_string` 中，如果第二行及之后的内容有tab前缀，替换结果中的tab数量**可能不等于你写的数量**，因为 Edit 会与 `old_string` 的边界字符（换行符、行尾空白）产生交互。**唯一安全的做法是用 Python 脚本按行号操作，完全避开字符串匹配。**

### 14.1 项目缩进对照表（🔴 核心参考，每次写代码前必须查阅）

本项目所有 GDScript 文件遵循统一缩进规范。以下是**精确的 tab 数对照表**，不是"大概"数字：

**类级别（class_name 下方，0tab）**：
| 代码结构 | tab数 | 示例 |
|----------|-------|------|
| signal/var/func 声明 | **0** | `signal hp_changed(new_hp: int, max_hp: int)` |
| func 声明行 | **0** | `func get_display_damage() -> int:` |

**函数体内（1tab起步）**：
| 代码结构 | tab数 | 示例 |
|----------|-------|------|
| match语句 | **1** | `match effect_id:` |
| if/elif/else条件 | **1** | `if card.get_display_cost() > energy:` |
| 函数体普通语句 | **1** | `energy -= actual_cost` |
| for循环 | **1** | `for card in hand:` |
| return语句 | **1** | `return damage if not is_upgraded else upgraded_damage` |

**match内部（2tab起步）**：
| 代码结构 | tab数 | 示例 |
|----------|-------|------|
| match pattern key `"xxx":` | **2** | `"gain_strength_1":` |
| match pattern 续行 | **2** | `"heal_low_hp", "purify", \` |
| match注释 | **2** | `# Skip effects already handled` |

**match pattern body（3tab起步）**：
| 代码结构 | tab数 | 示例 |
|----------|-------|------|
| pattern body语句 | **3** | `GameManager.strength_buff += 2` |
| pattern body的var/if | **3** | `var dmg = 3 + GameManager.strength_buff` |
| pattern body的注释 | **3** | `# First hit` |

**更深嵌套（4tab+）**：
| 代码结构 | tab数 | 示例 |
|----------|-------|------|
| pattern body内的if条件体 | **4** | `dmg += 3` |
| pattern body内的if嵌套if | **4** | `if GameManager.relics.has("subwoofer"):` |
| if内嵌套的语句 | **5** | `harmony_hit_bonus += 2` |

**🔴 常见错误对照（已经导致过的bug）**：
| 错误 | 正确 | 已经导致的后果 |
|------|------|---------------|
| func 写成1tab | func 应为0tab | CardData 解析失败 |
| match key 写成3tab | match key 应为2tab | BattleManager 解析失败（combo_2块） |
| match body 写成4tab | match body 应为3tab | BattleManager 解析失败（combo_2块） |
| return 写成2tab | return 应为1tab | CardData 解析失败 |

### 14.2 Python脚本写入代码的正确模板

**🔴 关键：Python中 `\t` = 1个tab。N个tab = N个`\t`。对照14.1的tab数表填写。**

```python
# ✅ 正确示例：在 battle_manager.gd 的 match 块中插入新分支
new_lines = [
    '\t\t"new_effect_id":\n',                      # 2tab ← match pattern key (对照表)
    '\t\t\tvar dmg = 5 + GameManager.strength_buff\n',  # 3tab ← pattern body (对照表)
    '\t\t\tif enemy_vulnerable > 0:\n',            # 3tab ← pattern body的if (对照表)
    '\t\t\t\tdmg = int(dmg * 1.5)\n',              # 4tab ← if内部 (对照表)
    '\t\t\t_apply_damage_to_enemy(dmg)\n',          # 3tab ← pattern body (对照表)
]

# ❌ 错误示例（已经导致过bug的写法！）
bad_lines = [
    '\t\t\t"new_effect_id":\n',    # 3tab ← ❌ 错了！match key应为2tab
    '\t\t\t\tvar dmg = 5\n',       # 4tab ← ❌ 错了！pattern body应为3tab
]
```

**插入代码**：
```python
with open('file.gd', 'r') as f:
    lines = f.readlines()
# 在第N行后插入（N从1开始）
result = lines[:N] + new_lines + lines[N:]
with open('file.gd', 'w') as f:
    f.writelines(result)
```

**替换代码**：
```python
with open('file.gd', 'r') as f:
    lines = f.readlines()
# 替换第START到第END行（1-indexed）
result = lines[:START-1] + new_lines + lines[END:]
with open('file.gd', 'w') as f:
    f.writelines(result)
```

### 14.3 续行符 `\`（⚠️ 多次踩坑）

> **🔴 续行符在 if 条件中不可靠！** 已证实 `if condition \
	and condition:` 会导致 Godot 4.6 解析报错 "Expected indented block after if block"。**禁止在 if 条件中使用续行符**。替代方案：① 用 `not x in ["a", "b", "c"]` 列表判断；② 拆成多个 if；③ 将条件存入变量。

GDScript 续行符是**单个反斜杠 + 真换行符**（字节：0x5c 0x0a），不是双反斜杠+字母n（字节：0x5c 0x5c 0x6e）。

```gdscript
# 正确的续行
"draw_2", "draw_2_skill_power", \
"heal_low_hp", "purify", "trade":
    pass
```

**Python写入规则**：
| 目标 | Python字符串 | 文件中的字节 | 说明 |
|------|-------------|-------------|------|
| 续行符 `\`+换行 | `'\\\n'` | 0x5c 0x0a | ✅ 正确：Python中 `\\`=一个`\`，`\n`=换行 |
| 双反斜杠+字母n | `'\\\\n'` | 0x5c 0x5c 0x6e | ❌ 错误：两个`\`字符+字母n |
| raw bytes方式 | `b'\x5c\x0a'` | 0x5c 0x0a | ✅ 正确：直接指定字节 |

**🔴 续行缩进**：续行比首行多1tab。例如：
- match pattern续行：首行2tab，续行**2tab**（与首行同级，只是跨行）
- return续行：首行1tab，续行**2tab**（比首行多1tab）

**验证续行符必须用raw bytes**：
```python
python3 -c "
with open('file.gd', 'rb') as f:
    data = f.read()
idx = data.find(b'effect_id_keyword')
print(repr(data[idx:idx+100]))
# 确认续行处是 0x5c 0x0a（\ + 换行），而非 0x5c 0x5c 0x6e（\\ + n）
"
```

### 14.4 match 块分支之间必须有空行或正确的缩进分隔

**🔴 新发现（combo_2 bug根因）**：当 match 的一个分支只有单行表达式（如 `GameManager.strength_buff += 2 if card.is_upgraded else 1`），且下一个分支紧跟其后时，GDScript 解析器会将下一个分支的 key 误认为是上一行的续行而非新的 match pattern。

**解决方案**：单行分支的语句结束后，必须在下一分支 key 前插入一个**空行**：

```gdscript
# ✅ 正确：空行分隔
"gain_strength_1":
    GameManager.strength_buff += 2 if card.is_upgraded else 1

"combo_2":
    var harmony_hit_bonus = 0
    ...

# ❌ 错误：无空行分隔（已导致解析失败！）
"gain_strength_1":
    GameManager.strength_buff += 2 if card.is_upgraded else 1
    "combo_2":   ← 解析器认为这是上一行表达式的一部分
```

### 14.5 三元表达式

GDScript 用 Python 风格：`value if condition else alternative`

**不能**用 C 风格 `condition ? true_val : false_val`

### 14.6 card_database.gd 默认升级值

```gdscript
card.upgraded_damage = entry.get("upgraded_damage", card.damage + 3 if card.damage > 0 else 0)
card.upgraded_block = entry.get("upgraded_block", card.block + 3 if card.block > 0 else 0)
card.upgraded_effect_text = entry.get("upgraded_effect_text", card.effect_text)
```

- **damage=0 的卡升级后不会凭空获得+3伤害**（之前会，导致弦音斩升级后多出3护盾）
- **所有卡牌必须显式写 `upgraded_effect_text`**：因为效果文本中的数字不会自动更新，不写则升级后描述不变

### 14.7 Power 牌升级设计

Power 牌打出后从牌组永久移除，不能靠"升级后多一个效果"来体现——因为打出时只执行一次。升级效果通过以下方式实现：

1. **数值增强**：升级时设置更大的值（如 power_harmony_flat_bonus: 2→3）
2. **门槛降低**：用 threshold 变量（如 power_beat_energy: 3→2）
3. **费用降低**：设置 `upgraded_cost: 0`
4. **额外属性**：设置附加变量（如 power_extra_gold、power_skill_dex）

**关键**：`_process_power_effect` 中必须检查 `card.is_upgraded` 来决定升级效果。

### 14.8 DEFENSE 分支的二级效果

`battle_manager.gd` 中：
- ATTACK 类型的卡如果 `get_display_block() > 0`，会在主伤害后额外加护盾（~line 177）
- DEFENSE 类型的卡如果 `get_display_damage() > 0`，会在主护盾后额外造成伤害（~line 184）

**因此**：攻防混合卡不需要特殊 effect_id，只需在 cards.json 中同时设 `damage` 和 `block`。但 effect_id 对应的效果（如 vulnerable_2）仍会额外执行。

**注意**：`gold_per_block_2` 类效果只需添加金币加成的护盾部分，基础护盾已由 DEFENSE 主分支处理。

### 14.9 和声延迟触发

`_trigger_harmony_effect()` 的调用在伤害/护盾计算**之后**（~line 203），否则 MYSTERIOUS 易伤会让触发卡自身享受易伤加成。`harmony_attribute` 和 `harmony_boosted` 变量在此延迟期间暂存。

### 14.10 first_attack/defense 标记时机

`first_attack_played_this_turn` / `first_defense_played_this_turn` 在 `play_card_effects()` **末尾**设置（~line 218），不在开头。因为遗物（pitch_pipe/music_stand）需要检查"本回合是否已打出过攻击/防御牌"，若在开头设置则第一张牌永远无法触发遗物效果。

### 14.11 bug历史记录（缩进/续行相关）

| # | 文件 | 日期 | 根因 | 具体错误 | 修复方式 |
|---|------|------|------|---------|---------|
| 1 | card_data.gd | 2026-06 | Python脚本缩进错 | func get_harmony_damage() 写成1tab(应为0tab) | Python按行号替换 |
| 2 | card_data.gd | 2026-06 | Python脚本缩进错 | is_harmony_card() return写成2tab(应为1tab) | Python按行号替换 |
| 3 | card_data.gd | 2026-06 | Python脚本续行符错 | 续行写成\\n(0x5c 0x5c 0x6e)而非\+换行(0x5c 0x0a) | raw bytes替换 |
| 4 | battle_manager.gd | 2026-06 | Python脚本缩进错 | combo_2 match key写成3tab(应为2tab), body写成4tab(应为3tab) | Python逐行减1tab |
| 5 | battle_manager.gd | 2026-06 | match单行分支无空行分隔 | gain_strength_1后紧跟combo_2，解析器将后者误认为前者的续行 | 插入空行 |
| 6 | game_manager.gd | 2026-06 | **Edit工具插入行导致tab错乱** | 用Edit在`var next_card_discount`前插入`var headphone_used`，new_string中保留了原行的`\n\t`，导致下一行多出1tab | Python按行号修正tab |
| 7 | score_scene.gd | 2026-06 | **GDScript不支持Python元组和解包语法** | `rows.append(("通关奖励", val))`元组语法报错；`for a, b in rows:`解包语法报错 | 改用`rows.append(["通关奖励", val])`数组+`for row_data in rows:`索引访问
| 8 | battle_manager.gd | 2026-06 | **GDScript续行符导致if条件解析失败** | `if a != "x" \` + 换行 + `and b != "y":` 报"Expected indented block after if block" | 改用列表判断，避免续行符
| 9 | battle_manager.gd | 2026-06-15 | **Edit工具反复替换同一行导致tab错乱** | 第119行`if`在match body内应为3tab，Edit反复替换后变成4tab，与代码体同级，报"Could not parse global class" | Python `line[1:]`去1tab

> **🔴 规律**：所有9次bug的根因都是"缩进/tab数量错误"或"续行符字节错误"。第1-5次是Python脚本写错tab数，第6/9次是Edit工具反复替换导致tab错乱。**无论用Python脚本还是Edit工具修改GDScript，修改后都必须立即用python3验证缩进。不得跳过。**

> **🔴 关键教训（Bug #9）**：对同一行反复调用 Edit 工具时，每次替换都可能悄悄改变该行的缩进层级。第119行原本3tab正确，经过3次Edit替换后变成4tab，且与下一行（也是4tab）处于同一层级——GDScript认为`if`块为空。**禁止对GDScript的任何行使用Edit工具进行反复替换，必须一次到位。如出错，用Python脚本按行号精确修正。**


### 14.12 GDScript 不支持 Python 元组和解包语法

GDScript **没有元组(tuple)类型**，也不支持 Python 风格的解包赋值：

```gdscript
# ❌ 错误：Python元组语法（GDScript会解析为分组表达式）
rows.append(("通关奖励", score_result.run_completion))

# ❌ 错误：Python解包语法
for label_text, points in rows:

# ✅ 正确：使用Array代替元组
rows.append(["通关奖励", score_result.run_completion])

# ✅ 正确：使用索引访问代替解包
for row_data in rows:
	var label_text: String = row_data[0]
	var points: int = row_data[1]
```

**根因**：GDScript中 `("a", 1)` 被解析为分组表达式（括号内的逗号表达式），而非元组字面量。`for a, b in rows:` 的解包语法也不存在，必须手动用索引取值。
---

## 15. 术语对照

| 中文 | 英文/代码术语 |
|------|-------------|
| 和声 | harmony |
| 消耗 | exhaust |
| 能力牌 | Power |
| 护盾 | block |
| 力量/敏捷 | strength_buff / dexterity_buff |
| 易伤 | vulnerable |
| 遗物 | relic |
| 多面指挥 | 類的专属机制（攻防混合+时机加成） |
| 升级 | upgrade / is_upgraded |
| 篝火 | campfire |
| 精英 | elite |
