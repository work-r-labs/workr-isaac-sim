"""Adds a "Workr Studio" collection to the Content browser for the assets asset-sync mirrors.

Modelled on Isaac Sim's own isaacsim.gui.content_browser, which registers the
"Isaac Sim" collection the same way.
"""

import weakref
from datetime import datetime
from pathlib import Path

import carb
import omni.client
import omni.ext
import omni.ui as ui
from omni.kit.widget.filebrowser import FileBrowserItemFields, NucleusItem
from omni.kit.window.content_browser import get_content_window
from omni.kit.window.filepicker import CollectionItem

ICON_PATH = Path(__file__).parent.parent.parent.joinpath("icons")
# Where docker-compose.yml mounts the scenes volume in the isaac-sim container.
LIBRARY_PATH = "/WORKR_STUDIO/library"


class WorkrFolderItem(NucleusItem):
    """A read-only folder under the Workr Studio collection."""

    def __init__(self, name: str, path: str) -> None:
        fields = FileBrowserItemFields(name, datetime.now(), 0, omni.client.AccessFlags.READ)
        super().__init__(path, fields, is_folder=True)
        self._models = (ui.SimpleStringModel(name), datetime.now(), ui.SimpleStringModel(""))
        self.icon = f"{ICON_PATH}/folder.svg"


class WorkrCollection(CollectionItem):
    """The "Workr Studio" entry in the Content browser's list of collections.

    Read-only, because the mirror is pull-only: asset-sync overwrites or prunes
    anything written into it.
    """

    def __init__(self) -> None:
        super().__init__(
            identifier="Workr Studio",
            title="Workr Studio",
            icon=f"{ICON_PATH}/workr.svg",
            access=omni.client.AccessFlags.READ,
            populated=False,
            # Isaac Sim's collection is 5; this sits just above it.
            order=4,
        )

    def create_add_new_item(self) -> None:
        # No "Add New Connection ..." row: the collection's one folder is fixed.
        return None

    def create_child_item(self, name: str, path: str, is_folder: bool = True) -> WorkrFolderItem:
        return WorkrFolderItem(name, path)

    async def populate_children_async(self) -> None:
        self.add_path("Library", LIBRARY_PATH)


class Extension(omni.ext.IExt):
    def on_startup(self, ext_id: str) -> None:
        self._collection = None
        self._window_ref = None

        window = get_content_window()
        if not window:
            carb.log_warn("workr.content_browser: no Content browser window; Workr Studio collection not added")
            return

        self._window_ref = weakref.ref(window)
        self._collection = WorkrCollection()
        window.api.register_collection_item(self._collection)

    def on_shutdown(self) -> None:
        window = self._window_ref() if self._window_ref else None
        if window and self._collection:
            window.api.deregister_collection_item(self._collection)
        self._collection = None
