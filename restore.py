from pathlib import Path
import shutil

os_folder = Path("os")
backup_folder = Path("backup/os")

if not backup_folder.exists():
    raise FileNotFoundError(f"Backup folder not found: {backup_folder}")

# Delete the existing os folder
if os_folder.exists():
    shutil.rmtree(os_folder)

# Restore it from the backup
shutil.copytree(backup_folder, os_folder)

print("Successfully restored 'os' from 'backup/os'.")