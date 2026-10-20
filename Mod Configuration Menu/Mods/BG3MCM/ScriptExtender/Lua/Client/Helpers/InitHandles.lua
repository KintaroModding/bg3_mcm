InitHandles = {}

local disabledMCMDefaultLabelHandle = "h6e8c611890eb4a589f1777131bebe79a2fcd"
local MCMActualLabel = Ext.Loca.GetTranslatedString("h8e2c39a3f3c040aebfb9ad10339dd4ff89f7")
Ext.Loca.UpdateTranslatedString(disabledMCMDefaultLabelHandle, MCMActualLabel)

-- bg3_mcm build: the sidebar toggle key and the text that named it are gone, so no handle needs an update.
function InitHandles:UpdateDynamicMCMWindowHandles()
end

return InitHandles
