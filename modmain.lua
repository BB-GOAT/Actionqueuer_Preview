GLOBAL.setmetatable(env, {
    __index = function(t, k)
        return GLOBAL.rawget(GLOBAL, k)
    end
})
local _G = GLOBAL
local KnownModIndex = _G.KnownModIndex

if not KnownModIndex:IsModEnabledAny("workshop-3136701076") then
    print("[黑化排队论 · 动作预览] 检测到黑化排队论本体未开启，停止加载！")
    return
end

if not rawget(_G, "BBGOAT_utils") then
    if TUNING.suggest_to_subscribe_bbgoat_basementmod then
        return
    end
    TUNING.suggest_to_subscribe_bbgoat_basementmod = true

	local function should_show_dig()
		if TheNet:IsDedicated() then
			return false
		end
		if not TheFrontEnd then
			return false
		end
		if IsMigrating() then
			return false
		end
		return not InGamePlay()
	end

	local _languages = {
		zh = true, -- Steam 中文
		zhr = true, -- WeGame 中文
		ch = true, -- 中文语言模组
		chs = true, -- 中文语言模组
		sc = true, -- 简体中文
		chinese = true, -- 中文语言模组
		zht = true, -- Steam 繁体中文
		tc = true, -- 繁体中文
		cht = true, -- 中文语言模组
	}
	local lang = _G.LanguageTranslator and _G.LanguageTranslator.defaultlang
	local isCH = lang and _languages[lang]

    AddGamePostInit(function()
        TheGlobalInstance:DoTaskInTime(0.1, function()
            if not should_show_dig() then return end
            local PopupDialogScreen = require "screens/redux/popupdialog"
            TheFrontEnd:PushScreen(PopupDialogScreen(
                modinfo.name,
                isCH and "模组基础运行库缺失！\n你缺少了模组基础运行库，你必须去订阅才能继续使用本模组" or
                        "Mod Runtime Library Missing!\nYou are missing the required runtime library for this mod. Please subscribe to it before continuing to use this mod.",
                {
                    {
                        text = isCH and "订阅/启用运行库模组" or "Subscribe/Enable mod",
                        cb = function()
                            local modname = "workshop-3750536829"
                            if table.contains(TheSim:GetModDirectoryNames(), modname) then
                                KnownModIndex:Enable(modname)
                                KnownModIndex:Save()
                                TheGlobalInstance:DoTaskInTime(0.5, function()
                                    TheNet:Disconnect(true)
                                    TheSim:ResetError()
                                    StartNextInstance()
                                end)
                            else
                                VisitURL("https://steamcommunity.com/sharedfiles/filedetails/?id=3750536829")
                                TheSim:SubscribeToMod("workshop-3750536829")
                                TheFrontEnd:PopScreen()
                                TheFrontEnd:PushScreen(PopupDialogScreen(
                                    isCH and "已订阅" or "Subscribed",
                                    isCH and "请前往模组列表启用【冰冰羊的模组运行库】模组" or "Please go to the mod list to enable the runtime library mod named\n\"BBGOAT Utils\"",
                                    {
                                        {
                                            text = isCH and "好的" or "OK",
                                            cb = function()
                                                TheFrontEnd:PopScreen()
                                            end
                                        }
                                    }
                                ))
                            end
                        end
                    },
                    {
                        text = isCH and "返回" or "Back",
                        cb = function()
                            TheFrontEnd:PopScreen()
                        end
                    },
                }
            ))
        end)
    end)
    return
end

local Upvaluehelper = _G.BBGOAT_utils.Upvaluehelper
local MOD_util = rawget(_G, "MOD_util")
if not MOD_util then
    print("[黑化排队论 · 动作预览] 未检测到萌萌的新-基础运行库，停止加载")
    return
end

Assets = {
    Asset("ANIM", "anim/farm_soil.zip"),
}

local function GetOption(name, default)
    return MOD_util:GetMOption(name, default)
end

-- 不预览的物品
local Blacklist = {
    abigail_flower = true, -- 阿巴盖尔之花（会炸）
    butterfly = true, -- 蝴蝶：无法预测-预测不准确 因为花朵有大有小
    minisign_item = true,  -- 小木牌：上级行为学Mod会乱放
    fertilizer = true, -- 便便桶 -- 萌萌的新的版本只会怼着一个地方施肥
    soil_amender_fermented = true, -- 超级催长剂 -- 萌萌的新的版本只会怼着一个地方施肥
    farm_plow_item = true, -- 耕地机 -- 萌萌的新的版本不能排队放置 -- ToDo: 我的预判也不大准确 横着放会少预判一个？ 20250702
}

local FindDeployHintItem -- 查找背包相同物品函数

local function IsValid(inst)
    return inst ~= nil and inst.IsValid ~= nil and inst:IsValid()
end

-- 只保存生成外观所需的信息，避免后续刷新依赖已经被游戏移除的源实体
local function FromSource(source, rotation, scale)
    if IsValid(source) and source.prefab then
        return {
            prefab = source.prefab, skin = source.skinname, skin_id = source.skin_id,
            rotation = rotation, scale = scale,
        }
    end
end

-- 建筑使用建筑放置虚影（placer）；部署物优先使用部署虚影，其他物品保留真实实体外观
local function GetSpec(queuer, item)
    local controller = queuer.inst and queuer.inst.components.playercontroller
    if item == nil and controller and controller.placer_recipe and IsValid(controller.placer) then
        return FromSource(controller.placer, controller.placer.Transform:GetRotation())
    end

    local source = FindDeployHintItem(queuer, item)
    if source == nil or Blacklist[source.prefab] then
        return
    end

    local inventory = queuer.inst.replica.inventory
    -- 装备工具时：耕地显示土堆，挖地皮和浇水显示放大的工具实体
    if inventory:GetActiveItem() == nil then
        if source.HasActionComponent and source:HasActionComponent("farmtiller") then
            return { prefab = "farm_soil" }
        elseif source.HasActionComponent and source:HasActionComponent("terraformer") or source.prefab == "wateringcan" or source.prefab == "premiumwateringcan" then
            return FromSource(source, nil, 2)
        end
    end
    if source:HasTag("groundtile") or source:HasTag("fertilizer") then -- 地皮、施肥
        return FromSource(source)
    end
    local inventoryitem = source.replica and source.replica.inventoryitem
    local wormwood_seed = queuer.inst:HasTag("plantkin") and source:HasTag("deployedfarmplant")
    if wormwood_seed or inventoryitem and inventoryitem:IsDeployable(queuer.inst) then
        local placer = controller and controller.deployplacer
        return IsValid(placer) and FromSource(placer, placer.Transform:GetRotation()) or FromSource(source)
    end
    return FromSource(source)
end

-- 记录返回值数量，转发被包装函数时保留中间及末尾的 nil
local function Pack(...)
    return { n = select("#", ...), ... }
end

-- 预览只执行客户端分支；生成和删除均为同步调用，结束后恢复原来的世界标志
local function InClientWorld(fn, ...)
    local TheWorld = _G.TheWorld
    local old_ismastersim = TheWorld.ismastersim
    TheWorld.ismastersim = false
    local result = Pack(fn(...))
    TheWorld.ismastersim = old_ismastersim
    return unpack(result, 1, result.n)
end

local function SpawnPreview(spec, userid)
    -- 执行完整预制体构造，保留皮肤、符号替换、组件及其他模组的初始化效果
    local inst = InClientWorld(SpawnPrefab, spec.prefab, spec.skin, spec.skin_id, userid)
    if inst == nil then return end
    if not IsValid(inst) or inst.Transform == nil or inst.AnimState == nil then
        if IsValid(inst) then InClientWorld(inst.Remove, inst) end
        return
    end
    inst.persists = false
    for _, tag in ipairs({ "fx", "FX", "DECOR", "NOCLICK", "NOBLOCK", "CLASSIFIED" }) do inst:AddTag(tag) end
    inst._aq_preview_entity = true
    -- 保存构造时的颜色，后续可恢复原色及原始透明度
    inst._aq_preview_mult = { inst.AnimState:GetMultColour() }
    inst._aq_preview_add = { inst.AnimState:GetAddColour() }
    inst._aq_preview_scale = { inst.Transform:GetScale() }
    inst._aq_preview_rotation = inst.Transform:GetRotation()
    inst:Hide()
    return inst
end

local function EmptyPreview()
    -- 不支持或生成失败时放入无动画的空实体，维持标记池接口，不回退成本体小木牌
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.persists = false
    inst._aq_preview_entity = true
    inst._aq_preview_empty = true
    for _, tag in ipairs({ "FX", "DECOR", "NOCLICK", "NOBLOCK", "CLASSIFIED" }) do inst:AddTag(tag) end
    inst:Hide()
    return inst
end

-- 设置外观/颜色
local function StylePreview(inst, spec)
    inst.Transform:SetRotation(spec.rotation or inst._aq_preview_rotation)
    if spec.scale ~= nil then
        inst.Transform:SetScale(spec.scale, spec.scale, spec.scale)
    else
        inst.Transform:SetScale(unpack(inst._aq_preview_scale))
    end
    local state = inst.AnimState
    state:SetMultColour(unpack(inst._aq_preview_mult))
    state:SetLightOverride(GetOption("preview_highlight", 0.3))
    if GetOption("preview_dont_color", false) then
        state:OverrideMultColour(1, 1, 1, 1)
        state:SetAddColour(unpack(inst._aq_preview_add))
    else
        local colour = PLAYERCOLOURS[GetOption("preview_color", "GREEN")] or PLAYERCOLOURS.GREEN
        state:OverrideMultColour(unpack(colour))
        state:SetAddColour(unpack(colour))
    end
end

local function InstallVisuals(queuer)
    if type(queuer) ~= "table" then return false, "未找到本体队列" end
    for _, name in ipairs({ "GetDeployHintMarker", "SetDeployHintMarkerAnim", "RefreshDeployHint",
        "HideUnusedDeployHintMarkers", "ClearDeployHint" }) do
        if type(queuer[name]) ~= "function" then return false, "本体缺少预览接口：" .. name end
    end
    FindDeployHintItem = Upvaluehelper.GetUpvalue(queuer.RefreshDeployHint, "FindDeployHintItem")
    if type(FindDeployHintItem) ~= "function" then return false, "无法取得本体物品查找函数" end

    local old_GetDeployHintMarker = queuer.GetDeployHintMarker
    local old_SetDeployHintMarkerAnim = queuer.SetDeployHintMarkerAnim
    local old_HideUnusedDeployHintMarkers = queuer.HideUnusedDeployHintMarkers
    local old_ClearDeployHint = queuer.ClearDeployHint

    queuer.SetDeployHintMarkerAnim = function(self, marker, ...)
        -- 完整预制体已自行设置动画和皮肤，跳过本体的通用动画替换
        if not marker or not marker._aq_preview_entity then return old_SetDeployHintMarkerAnim(self, marker, ...) end
    end
    queuer.GetDeployHintMarker = function(self, index, spacing, item, ...)
        local drawing = self._aq_preview_draw
        local spec = drawing and drawing.spec or (not drawing and GetSpec(self, item))
        self.deploy_hint_markers = self.deploy_hint_markers or {}
        local current = self.deploy_hint_markers[index]
        -- Paint 已按坐标对应旧实体；这里只比较 prefab 名称，其他外观变化直接更新。
        if not IsValid(current) or current._aq_preview_empty or not spec or current.prefab ~= spec.prefab then
            if IsValid(current) then InClientWorld(current.Remove, current) end
            current = spec and SpawnPreview(spec, self.inst.userid) or nil
            current = current or EmptyPreview()
            self.deploy_hint_markers[index] = current
        end
        -- 保留本体取标记的流程，再应用预制体原色及独立版外观设置
        local result = Pack(old_GetDeployHintMarker(self, index, spacing, item, ...))
        if result[1] and not current._aq_preview_empty then StylePreview(result[1], spec) end
        return unpack(result, 1, result.n)
    end
    queuer.HideUnusedDeployHintMarkers = function(self, count, ...)
        -- 本次未使用的实体立即删除，不留在本体池中等待复用
        for index, marker in pairs(self.deploy_hint_markers or {}) do
            if index > count then
                if IsValid(marker) then InClientWorld(marker.Remove, marker) end
                self.deploy_hint_markers[index] = nil
            end
        end
        return old_HideUnusedDeployHintMarkers(self, count, ...)
    end
    queuer.ClearDeployHint = function(self, remove, ...)
        -- 整段清理在客户端标志下执行，子实体和 prefab 自带的移除回调由游戏负责
        return InClientWorld(old_ClearDeployHint, self, true, ...)
    end
    return true
end


-- 兼容几何布局
local owners = setmetatable({}, { __mode = "k" })
local function GetGeometricSnap(queuer, deploy_fn, building)
    local root
    if building then
        -- 建造坐标由几何布局包装的建造接口修正
        local builder = queuer.inst.replica.builder
        root = builder and builder.MakeRecipeAtPoint
    elseif deploy_fn == queuer.DeployActiveItem then
        -- 普通右键部署在发送 RPC 时修正坐标；以下物品遵守几何布局的原有豁免规则
        local active = queuer.inst.replica.inventory:GetActiveItem()
        for _, tag in ipairs({ "wallbuilder", "fencebuilder", "gatebuilder", "groundtile" }) do
            if active and active:HasTag(tag) then return end
        end
        root = SendRPCToServer
    end
    -- 丢弃、耕地等其他动作不经过上述路径，因此不额外套用几何布局坐标
    if type(root) ~= "function" or not Upvaluehelper.FindUpvalue then return end
    local owner = owners[root]
    if owner == nil then
        -- 按模组来源限定闭包，避免误取其他模组同名的 Snap；找不到时缓存 false
        local _, _, found = Upvaluehelper.FindUpvalue(root, "Snap", "351325790")
        owner = found or false
        owners[root] = owner
    end
    if not owner then return end
    -- 只缓存闭包归属，不缓存上值本身：切换网格会替换 Snap，菜单也能改变 CTRL
    local snap = Upvaluehelper.GetUpvalue(owner, "Snap")
    local ctrl = Upvaluehelper.GetUpvalue(owner, "CTRL")

    if type(snap) == "function" and ctrl == TheInput:IsKeyDown(KEY_CTRL) then return snap end
end


-- 流程适配层：补充本体缺少的预览路径，包装接口而不替换动作执行器
-- 挖地皮、浇水和铺地皮使用地块位置队列；DEPLOY 仅接入带 groundtile 标签的地皮
local function PointAction(id, item)
    return id == "TERRAFORM" or id == "POUR_WATER_GROUNDTILE"
        or id == "DEPLOY" and item ~= nil and item:HasTag("groundtile")
end

-- 仅作为预览网格计算的动作占位，不执行实际部署
local function DummyDeploy() end

local function TilePreviewPosition(pos)
    -- 同一地皮内的点击位置和避障可达位置可能不同；这三种动作都以地皮为目标
    -- 仅将显示位置归到地皮中心，再由 Paint 去重，不修改本体实际动作的坐标
    return _G.Point(TheWorld.Map:GetTileCenterPoint(pos.x, 0, pos.z))
end

-- 拖动网格与执行队列使用相同顺序，物品不足时也显示同一组地块
local function SortPointPreviews(points)
    table.sort(points, function(a, b)
        return a.pos.x < b.pos.x or a.pos.x == b.pos.x and a.pos.z < b.pos.z
    end)
end

local function HeldItem(self)
    local inv = self.inst.replica.inventory
    return inv:GetActiveItem() or inv:GetEquippedItem(EQUIPSLOTS.HANDS)
end

-- 本体用 posaction 这个虚拟实体记录位置动作，读取它当前选中的动作类型
local function SelectedPointAction(self)
    local selected = self.posaction and self.selected_ents and self.selected_ents[self.posaction]
    return selected and PointAction(selected.id, selected.item or HeldItem(self)) and selected.id or nil
end

-- 同时检查地块条件和本体可获取的动作，避免显示当前工具无法操作的点位
local function CanPoint(self, id, pos, item)
    if id == "DEPLOY" then
        -- 物品耗尽时沿用本体查找下一组堆叠；传入实际物品检查动作，不移动物品
        item = FindDeployHintItem(self, item)
        local inventoryitem = item and item.replica and item.replica.inventoryitem
        return inventoryitem and inventoryitem.CanDeploy and inventoryitem:CanDeploy(pos, nil, self.inst)
            and not not self:GetAction(nil, id, nil, item, pos)
    end
    if id == "TERRAFORM" then
        if not TheWorld.Map:CanTerraformAtPoint(pos.x, 0, pos.z) then return false end
    elseif not TheWorld.Map:IsFarmableSoilAtPoint(pos.x, 0, pos.z) then
        return false
    end
    return not not self:GetAction(nil, id, nil, nil, pos)
end

local function InstallHooks(queuer)
    for _, name in ipairs({ "RefreshDeployHint", "ShowDeployHintMarker", "CanDeployHint",
        "HideUnusedDeployHintMarkers", "DeployToSelection", "ClearActionThread",
        "SelectEntity", "DeselectEntity", "selectallpos", "OnUp", "ClearDeployHint" }) do
        if type(queuer[name]) ~= "function" then return false, "本体缺少预览适配接口：" .. name end
    end
    local old_OnUp = queuer.OnUp
    local old_ClearDeployHint = queuer.ClearDeployHint
    local old_RefreshDeployHint = queuer.RefreshDeployHint
    local old_ShowDeployHintMarker = queuer.ShowDeployHintMarker
    local old_CanDeployHint = queuer.CanDeployHint
    local old_HideUnusedDeployHintMarkers = queuer.HideUnusedDeployHintMarkers
    local old_DeployToSelection = queuer.DeployToSelection
    local old_ClearActionThread = queuer.ClearActionThread
    local old_SelectEntity = queuer.SelectEntity
    local old_DeselectEntity = queuer.DeselectEntity
    local old_selectallpos = queuer.selectallpos
    -- 复用本体内部网格函数，使方向、间距及地皮起点的计算与本体一致
    local grid = Upvaluehelper.GetUpvalue(old_RefreshDeployHint, "redir_valid_pos")
    if type(grid) ~= "function" then return false, "无法取得本体的预览网格接口" end
    local get_limit = Upvaluehelper.GetUpvalue(old_RefreshDeployHint, "GetDeployHintLimit")
    if type(get_limit) ~= "function" then return false, "无法取得本体的预览数量接口" end
    local deploy_spacing = Upvaluehelper.GetUpvalue(old_OnUp, "deploy_spacing")
    local action_spacing = Upvaluehelper.GetUpvalue(old_OnUp, "action_spacing")
    if type(deploy_spacing) ~= "table" or type(action_spacing) ~= "table" then
        return false, "无法取得本体的位置动作间距"
    end
    -- 分别保存整批外观、位置动作信息、待刷新任务、本次收集点集和位置动作检查标志
    local batch, point_context, pending, collecting, point_mode, handing_off

    queuer.ClearDeployHint = function(self, remove, ...)
        -- 松手时保留拖动预览，直到部署执行器或位置队列接管，避免整批实体被删除重建。
        if handing_off and not remove then return end
        return old_ClearDeployHint(self, remove, ...)
    end
    queuer.OnUp = function(self, rightclick, ...)
        handing_off = self.clicked and not self.action_thread and (self.deploy_hint_count or 0) > 0
            and not self:IsWalkButtonDown()
            and (not next(self.selected_ents) or rightclick and SelectedPointAction(self))
        local result = Pack(old_OnUp(self, rightclick, ...))
        handing_off = nil
        -- 没有开始执行（例如被移动键打断）时立即清理，避免保留失去接管者的预览
        if not self.action_thread then self:ClearDeployHint(true) end
        return unpack(result, 1, result.n)
    end

    queuer.CanDeployHint = function(self, ...)
        local result = Pack(old_CanDeployHint(self, ...))
        -- 本体总开关关闭时返回 false，存在选中实体时返回 nil
        -- 仅在选中实体只有位置动作占位实体时放行，仍遵守总开关及真实实体选择限制
        if point_mode and result[1] == nil and self.selected_ents and self.posaction
            and self.selected_ents[self.posaction] then
            for ent in pairs(self.selected_ents) do if ent ~= self.posaction then return unpack(result, 1, result.n) end end
            return true
        end
        return unpack(result, 1, result.n)
    end

    queuer.ShowDeployHintMarker = function(self, index, pos, spacing, item, ...)
        if collecting then
            -- 本体循环复用同一个坐标对象，必须复制后保存，否则全部预览都会落到最后一点
            collecting[#collecting + 1] = { pos = Point(pos.x, 0, pos.z), spacing = spacing, item = item }
            return
        end
        return old_ShowDeployHintMarker(self, index, pos, spacing, item, ...)
    end
    queuer.HideUnusedDeployHintMarkers = function(self, count, ...)
        -- 收集期间先不隐藏，待坐标修正及去重后，用实际绘制数量统一收尾
        if not collecting then return old_HideUnusedDeployHintMarkers(self, count, ...) end
    end

    -- 对本体给出的点集做显示坐标修正、去重和额外筛选，再用连续索引绘制到本体池中
    local function Paint(self, points, spec, snap, filter, limit)
        local seen, count = {}, 0
        -- 只索引上一帧仍显示的实体；按坐标重新排入本体池，索引变化不会重播动画。
        local previous = {}
        self.deploy_hint_markers = self.deploy_hint_markers or {}
        for index, marker in pairs(self.deploy_hint_markers) do
            previous[marker._aq_preview_pos or marker] = marker
            self.deploy_hint_markers[index] = nil
        end
        -- 向外观层传递本次外观；即使 spec 为空，也不临时改取其他物品的外观
        self._aq_preview_draw = { spec = spec }
        for _, entry in ipairs(points) do
            -- 位置队列也遵守本体的物品总量限制；去重后再计数，避免偏移点占用名额
            if limit and count >= limit then break end
            -- 本体还用原坐标记录已处理点位，因此只能修正显示坐标，不能原地改动
            local pos = snap and snap(entry.pos) or entry.pos
            local key = string.format("%.6f:%.6f", pos.x, pos.z)
            if not seen[key] and (not filter or filter(pos)) then
                seen[key] = true
                count = count + 1
                self.deploy_hint_markers[count] = previous[key]
                previous[key] = nil
                old_ShowDeployHintMarker(self, count, pos, entry.spacing, entry.item)
                self.deploy_hint_markers[count]._aq_preview_pos = key
                -- 与当前本体标记数量上限一致，避免生成过多真实预览实体
                if count >= 400 then break end
            end
        end
        self._aq_preview_draw = nil
        -- 离开本次点集的实体立即删除，不保留隐藏缓存。
        for _, marker in pairs(previous) do
            if IsValid(marker) then InClientWorld(marker.Remove, marker) end
        end
        old_HideUnusedDeployHintMarkers(self, count)
    end

    queuer.RefreshDeployHint = function(self, deploy_fn, spacing, item, ...)
        -- 本体不会为位置动作传入部署函数；拖动中从选中的占位实体补出动作信息
        local id = not deploy_fn and self.clicked and self.TL and SelectedPointAction(self)
        local extra = Pack(...)
        local spec, snap, filter, limit
        if id then
            local selected = self.selected_ents[self.posaction]
            local active = self.inst.replica.inventory:GetActiveItem()
            spacing = active and deploy_spacing[active.prefab] or action_spacing[id] or 2
            item = FindDeployHintItem(self, selected.item or HeldItem(self))
            if not item then return self:ClearDeployHint() end
            spec = GetSpec(self, item)
            -- 借用挖地皮分支计算地皮起点和可达位置，再由各动作自己的条件筛选
            extra = Pack(nil, grid(self, self.TerraformAtPoint, spacing, item))
            -- 先收集网格点，再按地块去重和检查动作；重复点不能提前占用物品数量名额
            deploy_fn = DummyDeploy
            limit = id == "DEPLOY" and get_limit(self, self.DeployActiveItem, item) or nil
            snap = TilePreviewPosition
            filter = function(pos) return CanPoint(self, id, pos, item) end
            point_mode = true
        else
            -- 执行中使用整批外观快照，拖动阶段则读取当前物品或建筑虚影
            local current = batch and batch.deploy_fn == deploy_fn and batch or nil
            if current then spec = current.spec else spec = GetSpec(self, item) end
            local pc = self.inst.components.playercontroller
            local recipe = current and current.recipe or (item == nil and pc.placer_recipe)
            snap = GetGeometricSnap(self, deploy_fn, recipe ~= nil and recipe ~= false)
            if recipe then
                -- 建造首个建筑后当前配方可能被清空，继续用批次保存的配方检查剩余点位
                local rotation = current and current.rotation or (pc.placer and pc.placer:GetRotation() or 0)
                filter = function(pos)
                    local builder = self.inst.replica.builder
                    return builder and (builder:IsBuildBuffered(recipe.name) or builder:CanBuild(recipe.name))
                        and builder:CanBuildAtPoint(pos, recipe, rotation)
                end
            end
        end
        -- 先让原刷新函数完成网格遍历与数量限制，仅截取绘制调用；之后再统一绘制
        local points = {}
        collecting = points
        local result = Pack(old_RefreshDeployHint(self, deploy_fn, spacing, item, unpack(extra, 1, extra.n)))
        collecting, point_mode = nil, nil
        if id then SortPointPreviews(points) end
        Paint(self, points, spec, snap, filter, limit)
        return unpack(result, 1, result.n)
    end

    queuer.DeployToSelection = function(self, deploy_fn, spacing, item, ...)
        local pc = self.inst.components.playercontroller
        batch = { deploy_fn = deploy_fn, spec = GetSpec(self, item),
            recipe = item == nil and pc.placer_recipe or nil,
            rotation = pc.placer and pc.placer:GetRotation() or 0 }
        -- 游戏在首个建筑完成后会清空 pc.placer；整批保留预制体、皮肤、配方和旋转，
        -- 直到本体结束或中断动作，避免后续预览丢失建筑外观
        return old_DeployToSelection(self, deploy_fn, spacing, item, ...)
    end

    local function RefreshPointQueue(self)
        -- 拖动阶段由框选刷新负责；动作已停止时只能清理，不能让延迟任务重新显示预览
        if self.clicked or not point_context then return end
        if not self.action_thread then return self:ClearDeployHint() end
        local id, item = point_context.id, point_context.item
        point_mode = true
        local allowed = self:CanDeployHint()
        point_mode = nil
        if not allowed then return self:ClearDeployHint() end
        -- 本体会重置并替换整个队列表，必须每次重新读取上值，不能缓存旧表
        local queue = Upvaluehelper.GetUpvalue(old_selectallpos, "posaction_postab")
        local points = {}
        for pos, action in pairs(queue or {}) do
            if action == id and CanPoint(self, id, TilePreviewPosition(pos), item) then
                points[#points + 1] = { pos = pos, spacing = 4, item = item }
            end
        end
        -- 队列表的遍历顺序不固定，排序后按稳定顺序重建本次预览
        SortPointPreviews(points)
        local limit = id == "DEPLOY" and get_limit(self, self.DeployActiveItem, item) or nil
        Paint(self, points, point_context.spec, TilePreviewPosition, nil, limit)
    end
    local function Schedule(self)
        -- 合并同一帧的选中、取消选中通知，下一帧再读取本体更新完成后的剩余队列
        if pending or not point_context then return end
        pending = self.inst:DoTaskInTime(FRAMES, function()
            pending = nil
            if self.inst:IsValid() then RefreshPointQueue(self) end
        end)
    end
    queuer.selectallpos = function(self, id, spacing, item, ...)
        -- 本体启动位置框选队列后安排一次刷新，不另建持续运行的预览线程
        if PointAction(id, item) then
            point_context = { id = id, item = item, spec = GetSpec(self, item) }
        end
        local result = Pack(old_selectallpos(self, id, spacing, item, ...))
        Schedule(self)
        return unpack(result, 1, result.n)
    end
    queuer.SelectEntity = function(self, ent, id, item, ...)
        -- 位置动作每次重选目标都会经过这里，借此刷新剩余点位及当前工具外观
        local result = Pack(old_SelectEntity(self, ent, id, item, ...))
        item = item or HeldItem(self)
        if ent == self.posaction and PointAction(id, item) then
            point_context = { id = id, item = item, spec = GetSpec(self, item) }
            Schedule(self)
        end
        return unpack(result, 1, result.n)
    end
    queuer.DeselectEntity = function(self, ent, ...)
        -- 最后一个点执行完可能不再重选目标，取消选中时也要通知刷新以隐藏旧标记
        local result = Pack(old_DeselectEntity(self, ent, ...))
        if ent == self.posaction then Schedule(self) end
        return unpack(result, 1, result.n)
    end
    local function Reset()
        -- 取消待执行的刷新，并丢弃批次信息，防止上一批预览影响下一批动作
        if pending then pending:Cancel(); pending = nil end
        batch, point_context, handing_off = nil, nil, nil
    end
    queuer.ClearActionThread = function(self, ...)
        Reset()
        return old_ClearActionThread(self, ...)
    end
    queuer.inst:ListenForEvent("onremove", function()
        -- 玩家实体移除时一并清理，避免退出世界或更换实体后留下任务和预览实体
        Reset()
        queuer:ClearDeployHint(true)
    end)
    return true
end


AddComponentPostInit("playercontroller", function(controller, inst)
    if inst ~= ThePlayer then return end
    inst:DoTaskInTime(0, function()
        local queuer = Upvaluehelper.GetUpvalue(controller.OnControl, "ActionQueuer")
        local installed, reason = InstallVisuals(queuer)
        if not installed then
            print("[黑化排队论 · 动作预览] " .. reason)
            return
        end
        local adapted, detail = InstallHooks(queuer)
        if not adapted then
            print("[黑化排队论 · 动作预览] " .. detail)
        end
    end)
end)

if not MOD_util:CanAddSetting() then return end
local enabledisableoption = { { text = "禁用", data = false }, { text = "启用", data = true } }
MOD_util:CreatePage("排队论预览", {
    title = "黑化排队论 · 预览外观设置",
    buttondata = { name = "排队论预览" },
    order = 1,
    all_options = {
        {
            description = "预览亮度",
            key = "preview_highlight",
            default = 0.3,
            options = {
                { text = "10%", data = 0.1 }, { text = "20%", data = 0.2 },
                { text = "30%", data = 0.3 }, { text = "40%", data = 0.4 },
                { text = "50%", data = 0.5 }, { text = "60%", data = 0.6 },
                { text = "70%", data = 0.7 }, { text = "80%", data = 0.8 },
                { text = "90%", data = 0.9 }, { text = "100%", data = 1 },
            },
        },
        {
            description = "预览颜色",
            key = "preview_color",
            default = "GREEN",
            options = {
                { text = "白色", data = "WHITE" }, { text = "红色", data = "FIREBRICK" },
                { text = "橙色", data = "TAN" }, { text = "黄色", data = "LIGHTGOLD" },
                { text = "绿色", data = "GREEN" }, { text = "青色", data = "TEAL" },
                { text = "蓝色", data = "OTHERBLUE" }, { text = "紫色", data = "DARKPLUM" },
                { text = "粉色", data = "ROSYBROWN" }, { text = "金色", data = "GOLDENROD" },
            },
        },
        {
            description = "保留原色",
            key = "preview_dont_color",
            default = false,
            options = enabledisableoption,
        },
    },
})
