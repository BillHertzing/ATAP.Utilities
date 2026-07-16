# SyncfusionBlazorAssistant Prompt Template

Use this template to structure implementation instructions for the SyncfusionBlazorAssistant agent.

## Template

```markdown
# [Brief Title: e.g., "Update Navigation to Syncfusion Components"]

## Context (Optional)

- Syncfusion Version: [e.g., 24.2.3]
- Blazor Model: [Server/WebAssembly/Hybrid]
- Current State: [Brief description of what exists]
- Goal: [What you want to achieve]

---

## Change 1: [Brief Description]

**Target files:**

- [Path/To/File1.razor]
- [Path/To/File2.razor]
- [Path/To/File3.razor.css]

**Steps:**

1. [Specific action 1 - be precise about properties, values, placement]
2. [Specific action 2]
3. [Specific action 3]
4. [Add event handler: specify name, parameters, return type]
5. [Add/update styling: CSS classes, properties, values]

**Acceptance criteria:**

- [Observable behavior 1]
- [Observable behavior 2: including responsive breakpoints if applicable]
- [Observable behavior 3: including accessibility requirements]

---

## Change 2: [Brief Description]

**Target files:**

- [Path/To/File.razor]

**Steps:**

1. [Specific action]
2. [Specific action]

**Acceptance criteria:**

- [Observable behavior 1]
- [Observable behavior 2]

---

## Change 3: [Brief Description]

**Target files:**

- [Path/To/File.razor]

**Steps:**

1. [Specific action]

**Acceptance criteria:**

- [Observable behavior]

---

## Guardrails

- Don't reformat unrelated code
- Keep existing DI patterns
- Preserve existing event handlers for [specify areas]
- Maintain current CSS variables and theme integration
- Don't modify [specify files/components that should not change]
- [Any other specific constraints]

---

## Additional Notes (Optional)

- Known issues or considerations
- Dependencies that need to be installed
- Configuration changes required
- Testing recommendations
```

## Quick Start Examples

### Example 1: Simple Component Replacement

```markdown
# Replace Standard List with SfTreeView

## Change 1: Update NavMenu to use SfTreeView

**Target files:**

- Shared/NavMenu.razor
- Shared/NavMenu.razor.css

**Steps:**

1. Replace `<ul class="nav flex-column">` with `<SfTreeView TValue="NavItem">`
2. Set DataSource="@NavigationItems"
3. Add NodeTemplate for custom item rendering
4. Add NodeSelected="@OnNodeSelected" event handler
5. Add @code block with OnNodeSelected method that calls NavigationManager.NavigateTo
6. Update CSS to style .e-treeview nodes instead of .nav-item

**Acceptance criteria:**

- Tree displays all navigation items hierarchically
- Clicking an item navigates to the correct route
- Selected item is highlighted with .e-active class
- Items expand/collapse with click or arrow keys

## Guardrails

- Keep existing @inject NavigationManager
- Don't modify MainLayout.razor
- Preserve existing navigation routes
```

### Example 2: Multiple File Update

```markdown
# Modernize Layout with Syncfusion Components

## Change 1: Add SfAppBar to header

**Target files:**

- Shared/MainLayout.razor
- Shared/MainLayout.razor.css

**Steps:**

1. Add @using Syncfusion.Blazor.Navigations at top
2. Wrap existing header content in <SfAppBar ColorMode="AppBarColor.Primary">
3. Set Position="AppBarPosition.Fixed"
4. Add <AppBarSpacer /> before user profile section
5. Update CSS: remove custom header styles, use .e-appbar overrides for colors

**Acceptance criteria:**

- AppBar spans full viewport width
- Header is fixed at top during scroll
- Content below header has appropriate top margin

---

## Change 2: Replace sidebar with SfSidebar

**Target files:**

- Shared/MainLayout.razor
- Shared/NavMenu.razor

**Steps:**

1. In MainLayout, wrap <NavMenu /> in <SfSidebar>
2. Set Type="SidebarType.Push", Width="280px", MediaQuery="(min-width: 768px)"
3. Add @ref="sidebarRef" and create field in @code
4. Add toggle button in AppBar that calls sidebarRef.Toggle()
5. In NavMenu, ensure TreeView handles selection properly

**Acceptance criteria:**

- Sidebar pushes main content when opened
- Toggle button in AppBar shows/hides sidebar
- Automatically collapses below 768px
- Persists open state on desktop

## Guardrails

- Don't modify Pages/ folder
- Keep existing @layout directives
- Maintain all current @inject services
- Preserve custom CSS variables for theming
```

### Example 3: Progressive Enhancement

```markdown
# Add Advanced Features to Existing Grid

## Change 1: Enable SfGrid filtering and grouping

**Target files:**

- Pages/Products.razor

**Steps:**

1. Add AllowFiltering="true" to SfGrid
2. Add AllowGrouping="true" to SfGrid
3. Add <GridFilterSettings Type="FilterType.Excel" /> inside SfGrid
4. Add <GridGroupSettings ShowGroupedColumn="true" /> inside SfGrid
5. No event handler changes needed

**Acceptance criteria:**

- Filter icon appears in column headers
- Clicking filter opens Excel-style filter menu
- Users can drag column headers to group area
- Grouped rows are collapsible

---

## Change 2: Add toolbar with export buttons

**Target files:**

- Pages/Products.razor

**Steps:**

1. Add <GridToolbar> section inside SfGrid
2. Add <Toolbar Items="@(new List<string>() { "ExcelExport", "PdfExport" })" />
3. Add ToolbarClick="@OnToolbarClick" event
4. Implement OnToolbarClick method to handle "ExcelExport" and "PdfExport" operations
5. Call grid.ExcelExport() or grid.PdfExport() appropriately

**Acceptance criteria:**

- Toolbar appears above grid with two buttons
- Excel Export downloads .xlsx file with current grid data
- PDF Export downloads .pdf file with current grid data
- Exports respect current filters and grouping

## Guardrails

- Don't modify the GridColumns - keep existing configuration
- Keep existing OnRowSelected event handler
- Don't change the data loading logic
```

## Usage Instructions

1. **Copy the template** above or use one of the quick start examples
2. **Fill in all sections** with specific details:
   - Be precise about property names and values
   - Specify exact file paths
   - Include acceptance criteria for testing
3. **Review guardrails** - be explicit about what should NOT change
4. **Paste into VS Code** AI agent session with: "Implement these changes using the SyncfusionBlazorAssistant specification"
5. **Run build** after implementation: `dotnet build`
6. **Iterate** by pasting any errors back to the agent

## Tips for Effective Prompts

### Be Specific

❌ Bad: "Add a tree view"
✅ Good: "Replace `<ul>` in NavMenu.razor with `<SfTreeView TValue="NavItem" DataSource="@Items">`"

### Include Acceptance Criteria

❌ Bad: "Should look better"
✅ Good: "Sidebar collapses at 768px; selected item has .e-active class; keyboard navigation works"

### Specify Properties Exactly

❌ Bad: "Configure the sidebar properly"
✅ Good: "Set Type='SidebarType.Push', Width='280px', Dockbar='true'"

### List All Affected Files

❌ Bad: "Update the layout"
✅ Good: "Target files: Shared/MainLayout.razor, Shared/NavMenu.razor, Shared/NavMenu.razor.css"

### Include Event Handlers

❌ Bad: "Make it respond to clicks"
✅ Good: "Add NodeSelected='@OnNodeSelected' event; implement OnNodeSelected(NodeSelectEventArgs args) method to call NavigationManager.NavigateTo(args.NodeData.Url)"

## Common Syncfusion Components

Quick reference for component names and key properties:

- **SfSidebar**: Type, Width, Position, MediaQuery, @ref
- **SfTreeView**: TValue, DataSource, NodeTemplate, NodeSelected
- **SfAppBar**: ColorMode, Position, IsSticky
- **SfGrid**: TValue, DataSource, AllowPaging, AllowSorting, AllowFiltering, AllowGrouping
- **SfMenu**: Items, Orientation, Template
- **SfButton**: CssClass, Content, OnClick, IsPrimary
- **SfDialog**: Visible, Header, Content, Width, ShowCloseIcon
- **SfTab**: Items, HeaderShown, TabSelected

## Validation Checklist

Before submitting your prompt, verify:

- [ ] All target files are listed with correct paths
- [ ] Steps include specific property names and values
- [ ] Event handlers specify method signatures
- [ ] Acceptance criteria are observable/testable
- [ ] Guardrails protect existing functionality
- [ ] Context includes Syncfusion version if known
- [ ] Changes are numbered sequentially
- [ ] CSS changes specify exact selectors and properties

## Version History

- **v1.0** (2026-03-05): Initial prompt template for SyncfusionBlazorAssistant

## Related Files

- Agent Specification: `.claude/agents/SyncfusionBlazorAssistant.md`
- [Syncfusion Documentation:](https://blazor.syncfusion.com/documentation/)
