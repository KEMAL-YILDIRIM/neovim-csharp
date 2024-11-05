return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    --[[ dependencies = {
      'tree-sitter/tree-sitter-razor'
    }, ]]
    build = ':TSUpdate',
    config = function()
      -- [[ Configure Treesitter ]] See `:help nvim-treesitter`





      ---@diagnostic disable-next-line: missing-fields
      require('nvim-treesitter.configs').setup {
        ensure_installed = {
          'bash', 'c', 'html', 'css', 'lua', "markdown", "markdown_inline",
          'vim', 'vimdoc', 'c_sharp', 'sql', 'json', 'regex', 'javascript',
          'rust'
        },
        -- Autoinstall languages that are not installed
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
      }


      --[[ vim.api.nvim_create_autocmd("BufWinEnter", {
        pattern = "*.{razor,cshtml}",
        command = "set filetype=html.cshtml.razor",
      }) ]]


      -- There are additional nvim-treesitter modules that you can use to interact
      -- with nvim-treesitter. You should go explore a few and see what interests you:
      --
      --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
      --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
      --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
    end,
  },
  'nvim-treesitter/playground'
}
-- vim: ts=2 sts=2 sw=2 et