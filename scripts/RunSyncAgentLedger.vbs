Set shell = CreateObject("WScript.Shell")
rc = shell.Run("powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""C:\Users\Administrator\Desktop\Github Repos\agent-ledger\scripts\sync-agent-ledger.ps1""", 0, True)
WScript.Quit(rc)
