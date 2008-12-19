---------------------------------------------------------------------------
-- Stephan Lesch/Hilscher GmbH
-- Send feedback to SLesch@hilscher.com
---------------------------------------------------------------------------

module("nxoeditor", package.seeall)

require("tester")
require("gui_stuff")
createButton = gui_stuff.createButton
--createToggleButton = gui_stuff.createToggleButton

function createToggleButton(parentPanel, strLabel, eventFunction)
	local id = tester.nextID()
	local button = wx.wxToggleButton(parentPanel, id, strLabel)
	parentPanel:Connect(id, wx.wxEVT_COMMAND_TOGGLEBUTTON_CLICKED, eventFunction)
	return button
end

function createCheckBox(parentPanel, strLabel, fChecked, eventFunction)
	local id = tester.nextID()
	local checkbox = wx.wxCheckBox(parentPanel, id, strLabel)
	checkbox:SetValue(fChecked)
	parentPanel:Connect(id, wx.wxEVT_COMMAND_CHECKBOX_CLICKED , eventFunction)
	return checkbox
end

createRadioButton = gui_stuff.createRadioButton
createLabel = gui_stuff.createLabel
messageDialog = gui_stuff.messageDialog
errorDialog = gui_stuff.errorDialog
internalErrorDialog = gui_stuff.internalErrorDialog
require("utils")

muhkuh.include("taglist.lua", "taglist")
muhkuh.include("page_taglistedit.lua", "taglistedit")
muhkuh.include("nxo.lua", "nxo")
muhkuh.include("structedit.lua", "structedit")
muhkuh.include("hexdump.lua", "hexdump")

DEBUG = nil
m_nxo = nil

m_headerFilebar = nil
m_elfFilebar = nil
m_tagsFilebar = nil
m_nxoFilebar = nil

m_buttonCreateTags = nil
m_buttonDeleteTags = nil
m_buttonSizer = nil

-- the muhkuh panel for all gui objects
m_panel = nil 
m_paramPanel = nil

STATUS_OK = 0
STATUS_LOAD_ERROR = 1
STATUS_SAVE_ERROR = 2

---------------------------------------------------------------------
-- Button handlers
---------------------------------------------------------------------


local function OnQuit()
    muhkuh.TestHasFinished()
end

function OnHelp(event)
	local fVal = nxoeditor.m_checkboxHelp:GetValue()
	-- print("help", fVal)
	nxoeditor.displayHelp(fVal)
end

-- debug
local function OnCreateTags()
	nxoeditor.createEmptyParams()
	nxoeditor.setButtons()
end

-- debug
local function OnDeleteTags()
	taglistedit.destroyEditors()
	m_nxo:setTaglistBin(nil)
	m_fParamsLoaded = false
	nxoeditor.setButtons()
end

-- debug
function createEmptyParams()
	local bin = taglist.makeEmptyParblock()
	displayTags(bin)
	setButtons()
end


--- Display a taglist.
-- Parses a taglist, displays an error dialog and exits if parsing fails.
-- Otherwise, any currently displayed tag editors are removed, and the
-- new tags displayed.
-- @param abTags a binary taglist.
-- @return true if the list could be parsed and displayed, false otherwise.
function displayTags(abTags)
	-- parse data, show message dialog in case of errors
	local fOk, params, iLen, strMsg = taglist.binToParams(abTags, 0)
	if not fOk then
		errorDialog("Error parsing parameters", strMsg)
		return false
	end
	-- remove any old editors/controls
	if m_fParamsLoaded then
		taglistedit.destroyEditors()
	end
	-- create the new controls
	taglistedit.createEditors(params)
	m_panel:Layout()
	m_panel:Refresh()
	m_panel:Update()
	m_fParamsLoaded = true
	
	return true
end


---------------------------------------------------------------------
-- loading and saving
---------------------------------------------------------------------
strHdrFilenameFilters = "BIN files (*.bin)|*.bin|All Files (*)|*"
strElfFilenameFilters = "ELF files (*.elf)|*.elf|All Files (*)|*"
strTagFilenameFilters = "BIN files (*.bin)|*.bin|All Files (*)|*"
strNxoFilenameFilters = "NXO files (*.nxo)|*.nxo|All Files (*)|*"

function loadFileDialog(parent, strTitle, strFilters)
	local fileDialog = wx.wxFileDialog(
		parent, 
		strTitle or "Select file to load",
		"",
		"", 
		strFilters,
		wx.wxFD_OPEN + wx.wxFD_FILE_MUST_EXIST)
	local iResult = fileDialog:ShowModal()
	local strFilename
	if iResult == wx.wxID_OK then
		strFilename = fileDialog:GetPath()
	end
	fileDialog:Destroy()
	return strFilename
end

function saveFileDialog(parent, strTitle, strFilters)
	local fileDialog = wx.wxFileDialog(
		parent, 
		strTitle or "Select file to save to",
		"",
		"", 
		strFilters,
		wx.wxFD_SAVE + wx.wxFD_OVERWRITE_PROMPT)
	local iResult = fileDialog:ShowModal()
	local strFilename
	if iResult == wx.wxID_OK then
		strFilename = fileDialog:GetPath()
	end
	fileDialog:Destroy()
	return strFilename
end


function loadFile(strFilename)
	local strBin, strMsg = utils.loadBin(strFilename)
	if strBin then 
		return STATUS_OK, strBin 
	else
		errorDialog("Load error", strMsg)
		return STATUS_LOAD_ERROR
	end
	
end

function saveFile(strFilename, strBin)
	local fOk, strmsg = utils.writeBin(strFilename, strBin)
	if fOk then
		return STATUS_OK
	else
		errorDialog("Save error", strmsg)
		return STATUS_SAVE_ERROR
	end
end

function saveFile1(filebar, fSaveAs, strTitle, strFilenameFilters, abBin)
	local strFilename = filebar:getFilename()
	if fSaveAs or strFilename:len()==0 then
		strFilename = saveFileDialog(m_panel, strTitle, strFilenameFilters)
	end
	if not strFilename then return end
	
	local iStatus = saveFile(strFilename, abBin)
	if iStatus==STATUS_OK then
		filebar:setFilename(strFilename)
		setButtons()
	end
end


function loadHdr(filebar)
	local strFilename = loadFileDialog(m_panel, "Select header file", strHdrFilenameFilters)
	if not strFilename then return end
	local iStatus, abBin = loadFile(strFilename)
	if iStatus==STATUS_OK then
		m_nxo:setHeadersBin(abBin)
		filebar:setFilename(strFilename)
		setButtons()
	end
end

function saveHdr(filebar, fSaveAs)
	local abBin = m_nxo:getHeadersBin()
	saveFile1(filebar, fSaveAs, "Save headers as", strHdrFilenameFilters, abBin)
end


function loadElf(filebar)
	local strFilename = loadFileDialog(m_panel, "Select Elf file", strElfFilenameFilters)
	if not strFilename then return end
	local iStatus, abBin = loadFile(strFilename)
	if iStatus==STATUS_OK then
		m_nxo:setElf(abBin)
		filebar:setFilename(strFilename)
		setButtons()
	end
end

function saveElf(filebar, fSaveAs)
	local abBin = m_nxo:getElf()
	saveFile1(filebar, fSaveAs, "Save Elf as", strElfFilenameFilters, abBin)
end

function loadTags(filebar)
	local strFilename = loadFileDialog(m_panel, "Select Taglist file", strTagFilenameFilters)
	if not strFilename then return end
	local iStatus, abBin = loadFile(strFilename)
	if iStatus==STATUS_OK and displayTags(abBin) then
		m_nxo:setTaglistBin(abBin)
		filebar:setFilename(strFilename)
		setButtons()
	end
end


function saveTags(filebar, fSaveAs)
	-- get taglist
	local abBin = taglistedit.getTagBin()
	if abBin then
		saveFile1(filebar, fSaveAs, "Save taglist as", strTagFilenameFilters, abBin)
	end
end

-- todo: error handling, display tags if parsed correctly
function loadNxo(filebar)
	local strFilename = loadFileDialog(m_panel, "Select NXO file", strNxoFilenameFilters)
	if not strFilename then return end
	local iStatus, abBin = loadFile(strFilename)
	-- loaded successfully
	if iStatus==STATUS_OK then
		local fOk, astrErrors = m_nxo:parseNxoBin(abBin)
		-- parsed successfully
		if fOk then
			filebar:setFilename(strFilename)
			setButtons()
			local abTags = m_nxo:getTaglistBin()
				-- has tags
				if abTags then
					local fOk = displayTags(abTags)
					if not fOk then 
						-- error parsing taglist
						messageDialog("Error parsing taglist")
					end
				else
					-- has no tags
					messageDialog("No taglist found", "No taglist found")
				end
		else
			-- error parsing file
			local strErrors = table.concat(astrErrors, "\n") 
			if strErrors == "" then strErrors = "Unknown error" end
			errorDialog("Error opening NXO file", strErrors)
			
		end
	end
	
end


function saveNxo(filebar, fSaveAs)
	-- get taglist
	local abTags = taglistedit.getTagBin()
	if not abTags then
		return
	end
	
	m_nxo:setTaglistBin(abTags)
	
	-- build nxo file
	local abNxoFile = m_nxo:buildNxoBin()
	if not abNxoFile then
		errorDialog("Error", "Failed to build NXO file")
		return
	end

	saveFile1(filebar, fSaveAs, "Save NXO as", strNxoFilenameFilters, abNxoFile)
end

--- Enable/disable load/save buttons depending on which data is in memory.
-- loading is always possible,
-- save/save as for headers, ELF and taglist is only possible if header/data/tags are in memory
-- save NXO (as) is possible when headers ,elf and tags data are in memory.
function setButtons()
	local fHeaders = m_nxo:hasHeaders()
	local fElf = m_nxo:hasElf()
	local fTags = m_nxo:hasTaglist()
	local fComplete = m_nxo:isComplete()
	
	m_headerFilebar:enableButtons(true, fHeaders, fHeaders)
	m_elfFilebar:enableButtons(true, fElf, fElf)
	m_tagsFilebar:enableButtons(true, fTags, fTags)
	m_nxoFilebar:enableButtons(true, fComplete, fComplete)

	if DEBUG then
		m_buttonCreateTags:Enable(not fTags)
		m_buttonDeleteTags:Enable(fTags)
	end
end


---------------------------------------------------------------------
-- a bar consisting of a label, textbox for a filename and
-- load/save as/save buttons
---------------------------------------------------------------------
function filebar_setFilename(filebar, strFilename)
	filebar.m_textctrl:SetValue(strFilename)
end

function filebar_getFilename(filebar, strFilename)
	return filebar.m_textctrl:GetValue(strFilename)
end

function filebar_enableButtons(filebar, fLoad, fSave, fSaveAs)
	if filebar.m_buttonLoad then filebar.m_buttonLoad:Enable(fLoad) end
	if filebar.m_buttonSaveAs then filebar.m_buttonSaveAs:Enable(fSaveAs) end
	if filebar.m_buttonSave then filebar.m_buttonSave:Enable(fSave) end
end

function insertFilebar(parent, sizer, strStaticText, fnLoad, fnSave)
	-- create elements
	local filebar = {}
	local label = createLabel(parent, strStaticText)
	local textctrl = wx.wxTextCtrl(parent, wx.wxID_ANY)
	textctrl:SetEditable(false)
	local buttonLoad, buttonSaveAs, buttonSave
	if fnLoad then
		buttonLoad = createButton(parent, "Load", function() fnLoad(filebar) end)
	end
	if fnSave then
		buttonSaveAs = createButton(parent, "Save as", function() fnSave(filebar, true) end)
		buttonSave = createButton(parent, "Save", function() fnSave(filebar, false) end)
	end

	-- add to sizer
	sizer:Add(label, 0, wx.wxALIGN_CENTER_VERTICAL)
	sizer:Add(textctrl, 1, wx.wxEXPAND + wx.wxALIGN_CENTER_VERTICAL)
	if buttonLoad then 
		sizer:Add(buttonLoad, 0, wx.wxALIGN_CENTER_VERTICAL) 
	else
		print("spacer")
		sizer:AddSpacer(0)
	end
	if buttonSaveAs then 
		sizer:Add(buttonSaveAs, 0, wx.wxALIGN_CENTER_VERTICAL) 
	else
		print("spacer")
		sizer:AddSpacer(0)
	end
	if buttonSave then 
		sizer:Add(buttonSave, 0, wx.wxALIGN_CENTER_VERTICAL) 
	else
		print("spacer")
		sizer:AddSpacer(0)
	end

	-- put into table
	filebar.m_label = label
	filebar.m_textctrl = textctrl
	filebar.m_buttonLoad = buttonLoad
	filebar.m_buttonSaveAs = buttonSaveAs
	filebar.m_buttonSave = buttonSave
	filebar.setFilename = filebar_setFilename
	filebar.getFilename = filebar_getFilename
	filebar.enableButtons = filebar_enableButtons
	
	return filebar
end

---------------------------------------------------------------------
-- create GUI at startup
---------------------------------------------------------------------
function createPanel()
	m_splitterPanel = wx.wxSplitterWindow(m_panel, wx.wxID_ANY)--, wx.wxDefaultPosition ,wx.wxDefaultSize, wx.wxSP_3D + wx.wxSP_PERMIT_UNSPLIT)
	m_leftPanel = wx.wxPanel(m_splitterPanel, wx.wxID_ANY)

	-- Tag editor
	local parent = m_leftPanel
	m_paramPanel = taglistedit.createTaglistPanel(parent)
	
	-- Filename/load/save
	local fileSizer = wx.wxFlexGridSizer(4, 5, 3, 3)
	fileSizer:AddGrowableCol(1, 1)

	m_headerFilebar = insertFilebar(parent, fileSizer, "Headers", loadHdr, saveHdr)
	m_elfFilebar = insertFilebar(parent, fileSizer, "ELF", loadElf, saveElf)
	m_tagsFilebar = insertFilebar(parent, fileSizer, "Taglist", loadTags, saveTags)
	m_nxoFilebar = insertFilebar(parent, fileSizer, "NXO", loadNxo, saveNxo)
	
	local inputSizer = wx.wxStaticBoxSizer(wx.wxHORIZONTAL, parent, "Load/Save")
	inputSizer:Add(fileSizer, 1, wx.wxEXPAND)

	-- HTML help window
	m_helpWindow = wx.wxHtmlWindow(m_splitterPanel)
	
	-- quit / create Params / delete params buttons
	m_buttonQuit = createButton(m_panel, "Quit", OnQuit)
	m_checkboxHelp = createCheckBox(m_panel, "Display Help", true, OnHelp)
	
	m_buttonState = false
	m_buttonSizer = wx.wxBoxSizer(wx.wxHORIZONTAL)
	m_buttonSizer:Add(m_buttonQuit, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 3)
	m_buttonSizer:Add(m_checkboxHelp, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 3)
	
	if DEBUG then
		m_buttonCreateTags = createButton(m_panel, "Create Empty Parameters", OnCreateTags)
		m_buttonDeleteTags = createButton(m_panel, "Delete Parameters", OnDeleteTags)
		m_buttonSizer:Add(m_buttonCreateTags, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 3)
		m_buttonSizer:Add(m_buttonDeleteTags, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 3)
	end
	
	-- combine 
	local leftSizer = wx.wxBoxSizer(wx.wxVERTICAL)
	leftSizer:Add(m_paramPanel, 1, wx.wxEXPAND + wx.wxALL, 3)
	leftSizer:Add(inputSizer, 0, wx.wxEXPAND + wx.wxALL, 3)
	m_leftPanel:SetSizer(leftSizer)
	
	m_splitterPanel:SetSashGravity(0.3)
	m_splitterPanel:SetMinimumPaneSize(20)
	m_splitterPanel:SplitVertically(m_leftPanel, m_helpWindow)
	
	local mainSizer = wx.wxBoxSizer(wx.wxVERTICAL)
	mainSizer:Add(m_splitterPanel, 1, wx.wxEXPAND + wx.wxALL, 3)
	mainSizer:Add(m_buttonSizer, 0, wx.wxALL, 3)
	
	setButtons()
	m_panel:SetSizer(mainSizer)
	m_panel:Layout()
	m_panel:Refresh()
end


---------------------------------------------------------------------
--          handle the help viewer
---------------------------------------------------------------------

m_fShowHelp = true
m_dSplitRatio = 0.5

-- @param fShow hide or show help area
function displayHelp(fShow)
	-- print("displayHelp: ", fShow)
	m_fShowHelp = fShow
	if fShow then
		m_splitterPanel:SetSashGravity(0.3)
		m_splitterPanel:SetMinimumPaneSize(20)
		local iWidth = m_splitterPanel:GetSize():GetWidth()
		local iPos = iWidth * m_dSplitRatio
		m_splitterPanel:SplitVertically(m_leftPanel, m_helpWindow)
		m_splitterPanel:SetSashPosition(iPos)
		-- print("iPos: ", iPos, "iWidth: ", iWidth, "sash rel pos:", m_dSplitRatio)
	else
		local iPos = m_splitterPanel:GetSashPosition()
		local iWidth = m_splitterPanel:GetSize():GetWidth()
		m_dSplitRatio = iPos/iWidth
		-- print("iPos: ", iPos, "iWidth: ", iWidth, "sash rel pos:", m_dSashRelPos)
		m_splitterPanel:Unsplit()
	end
	m_panel:Layout()
	m_panel:Refresh()
end

--- Show help for a tag description
function showTagHelp(tTagDesc)
	if not m_fShowHelp then
		return
	end
	
	local strPageFilename, strAnchor = taglist.getTagHelp(tTagDesc)
	if not strPageFilename then
		return
	end
	
	local strPageSource = muhkuh.load("help/"..strPageFilename)
	if strPageSource then
		m_helpWindow:SetPage(strPageSource)
	
		if strAnchor then
			m_helpWindow:LoadPage(strAnchor)
		end
	else
		print("error loading help page: page = ", strPageFilename)
	end
end
---------------------------------------------------------------------
------------------------------  test
---------------------------------------------------------------------


function printParamList(paramList)
	for _, par in pairs(paramList) do
		-- print tag, data size and hexdump
		print(string.format("type: 0x%08x len: %d data:\n", par.ulTag, par.ulSize) ..
		hexdump.hexString(par.abValue, "", 16))
	end

end

function tryExtract(origbin, trybin)
	local fOk, params, iLen, strMsg = taglist.binToParams(trybin, 0)
	print("binToParam status: ", fOk)
	print("message:", strMsg)
	print("len: ", iLen)
	printParamList(params)
end

-- self:setStyle("0x%08x: ", 16, " ", true, wx.wxTE_MULTILINE)
function test()
	local bin = taglist.makeEmptyParblock()
	assert(bin, "failed to generate param block")
	print("parblock: ")
	hexdump.printHex(bin, "0x%08x", 16, true)
	local junk = "tritratrullallabullatrullahoppsassa"
	tryExtract(bin, bin..junk)
	tryExtract(bin, junk)

	local fOk, params, iLen, strMsg = taglist.binToParams(bin, 0)
	printParamList(params)
	local rebin = taglist.paramsToBin(params)
	hexdump.printHex(rebin, "0x%08x", 16, true)
end
---------------------------------------------------------------------
-- startup function, called by the code snippet in test_description.xml

function run()
	m_nxo = nxo.new()
	m_panel = __MUHKUH_PANEL
	createPanel()
	m_helpController = nil
end
