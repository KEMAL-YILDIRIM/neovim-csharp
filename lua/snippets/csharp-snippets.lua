local ls = require("luasnip")
local s = ls.snippet     -- creator
local i = ls.insert_node --nodes
local t = ls.text_node
local f = ls.function_node
local fmt = require("luasnip.extras.fmt").fmt

local function get_namespace()
    -- Get the current buffer's file path
    local file_path = vim.fn.expand("%:p")
    -- Get the project root (assuming it contains .sln or .csproj file)
    local project_root = vim.fn.fnamemodify(vim.fn.findfile(".sln", ".;"), ":h")
    if project_root == "" then
        project_root = vim.fn.fnamemodify(vim.fn.findfile(".csproj", ".;"), ":h")
    end

    -- Get relative path from project root to current file
    local rel_path = file_path:sub(#project_root + 2)
    -- Remove the filename
    local dir_path = vim.fn.fnamemodify(rel_path, ":h")
    -- Convert directory separators to dots and remove any special characters
    local namespace = dir_path:gsub("[/\\]", "."):gsub("[^%w.]", "")

    -- If we're in the root, use the project name
    if namespace == "" then
        namespace = vim.fn.fnamemodify(project_root, ":t")
    else
        namespace = vim.fn.fnamemodify(project_root, ":t") .. "." .. namespace
    end

    return namespace
end


-- Function to get class information from Roslyn LSP
local function get_class_info()
    local params = {
        textDocument = vim.lsp.util.make_text_document_params(),
        position = vim.lsp.util.make_position_params().position
    }

    local result = vim.lsp.buf_request_sync(0, 'textDocument/semanticTokens/full', params, 1000)
    local symbols = vim.lsp.buf_request_sync(0, 'textDocument/documentSymbol', params, 1000)

    if not symbols then return nil end

    for _, res in pairs(symbols) do
        if res.result then
            for _, symbol in ipairs(res.result) do
                if symbol.kind == 5 then -- ClassSymbol
                    return {
                        name = symbol.name,
                        range = symbol.range,
                        detail = symbol.detail
                    }
                end
            end
        end
    end
    return nil
end

-- Function to get class fields from Roslyn LSP
local function get_class_fields()
    local params = {
        textDocument = vim.lsp.util.make_text_document_params(),
        position = vim.lsp.util.make_position_params().position
    }

    local result = vim.lsp.buf_request_sync(0, 'textDocument/documentSymbol', params, 1000)
    local fields = {}

    if not result then return fields end

    for _, res in pairs(result) do
        if res.result then
            for _, symbol in ipairs(res.result) do
                if symbol.kind == 5 then -- Class
                    -- Process children of the class
                    if symbol.children then
                        for _, child in ipairs(symbol.children) do
                            if child.kind == 8 then -- Field
                                table.insert(fields, {
                                    name = child.name,
                                    detail = child.detail,
                                    range = child.range
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    return fields
end

-- Parse Roslyn field detail into components
local function parse_field_detail(detail)
    -- Roslyn provides details in format like "private string _name"
    local pattern = "(%w+)%s+([%w%.<>]+)%s+([_%w]+)"
    local access, type, name = detail:match(pattern)

    if access and type and name then
        return {
            access = access,
            type = type,
            name = name:gsub("^_", "") -- Remove leading underscore if present
        }
    end
    return nil
end

local function generate_constructor_params(args)
    local fields = get_class_fields()
    local params = {}

    for _, field in ipairs(fields) do
        local parsed = parse_field_detail(field.detail)
        if parsed and parsed.access == "private" then -- Only include private fields
            table.insert(params, parsed.type .. " " .. parsed.name)
        end
    end

    return table.concat(params, ", ")
end

local function generate_assignments(args)
    local fields = get_class_fields()
    local assignments = {}

    for _, field in ipairs(fields) do
        local parsed = parse_field_detail(field.detail)
        if parsed and parsed.access == "private" then -- Only include private fields
            local fieldName = parsed.name
            local thisRef = "_" .. fieldName          -- Use backing field if it exists
            table.insert(assignments, string.format("        this.%s = %s;", thisRef, fieldName))
        end
    end

    return #assignments > 0 and "\n" .. table.concat(assignments, "\n") or ""
end

ls.add_snippets("cs", {

    s("iface", fmt([[
using System;

namespace {}
{{
    public interface {}
    {{
        {}
    }}
}}
    ]], {
        f(get_namespace),
        i(1, "InterfaceName"),
        i(0)
    })),

    s("class", fmt([[
using System;

namespace {}
{{
    public class {}
    {{
        {}
    }}
}}
    ]], {
        f(get_namespace),
        i(1, "ClassName"),
        i(0)
    })),

    s("ctor", {
        t({ "    /// <summary>", "    /// Initializes a new instance of the " }),
        f(function()
            local class_info = get_class_info()
            return class_info and class_info.name or "ClassName"
        end, {}),
        t({ " class.", "    /// </summary>" }),
        -- Generate parameter documentation
        f(function()
            local fields = get_class_fields()
            local docs = {}
            for _, field in ipairs(fields) do
                local parsed = parse_field_detail(field.detail)
                if parsed and parsed.access == "private" then
                    table.insert(docs, string.format("    /// <param name=\"%s\">The %s.</param>",
                        parsed.name, parsed.name:gsub("([A-Z])", " %1"):lower():trim()))
                end
            end
            return #docs > 0 and "\n" .. table.concat(docs, "\n") or ""
        end, {}),
        t({ "", "    public " }),
        -- Class name
        f(function()
            local class_info = get_class_info()
            return class_info and class_info.name or "ClassName"
        end, {}),
        t("("),
        -- Constructor parameters
        f(generate_constructor_params, {}),
        t({ ") {", "" }),
        -- Field assignments
        f(generate_assignments, {}),
        t({ "", "    }" })
    })

})