# Handle edits

```{note}
Users can edit content in their own libraries. Moderators don't need to approve these edits. The edits appear in the __Edits__ queue to give admins and moderators a full timeline of changes. 
```

Users can suggest metadata edits on objects they can access. When a user suggests an edit, it's sent to the __Edits__ queue for review. Moderators and pod admins can accept or reject these edits.

```{dropdown} Required permissions
- {guilabel}`Moderation` – provides access to the administration menu.
- {guilabel}`Library` – provides access to the library menu.
```

Each edit object contains the following information:

- A {guilabel}`Modification` ID – the unique ID of the modification. Select this to show the modification in context with the edited object.
- A timestamp of when the user suggested the edit.
- The status of the edit.
- The {guilabel}`Field` that the user edited.
- The {guilabel}`Old value` that the user edited.
- The {guilabel}`New value` that the user entered.
- The user who suggested the edit.

To review suggested edits:

```{tabbed} Desktop

1. Log in to your {term}`pod`.
2. Select the wrench icon ({fa}`wrench`) at the top of the sidebar to open the {guilabel}`Administration` menu.
3. Select {guilabel}`Library`. The {guilabel}`Edits` page opens. The {guilabel}`Library edits` section displays a list of unresolved edits.
4. Review the edit and select on of the following options:
   - {guilabel}`Approve` – approve the edit and apply it to the object.
   - {guilabel}`Reject` – reject the edit and leave the object in its current state.
   - {guilabel}`Delete` – delete the edit suggestion without taking further action. The object remains in its current state.

```

```{tabbed} Mobile

1. Log in to your {term}`pod`.
2. Select the wrench icon ({fa}`wrench`) at the top of the screen to open the {guilabel}`Administration` menu.
3. Select {guilabel}`Library`. The {guilabel}`Edits` page opens. The {guilabel}`Library edits` section displays a list of unresolved edits.
4. Review the edit and select on of the following options:
   - {guilabel}`Approve` – approve the edit and apply it to the object.
   - {guilabel}`Reject` – reject the edit and leave the object in its current state.
   - {guilabel}`Delete` – delete the edit suggestion without taking further action. The object remains in its current state.

```

That's it! You've handled the edit request. You can use the filters on this page to search for historical requests.
