-- Automatic Printing Program
-- Just enter text to print

-- Get user input
write("Enter text to print: ")
local text = read()

-- Find connected printer
local printer
for _, side in ipairs(peripheral.getNames()) do
    if peripheral.getType(side) == "printer" then
        printer = peripheral.wrap(side)
        break
    end
end

-- Attempt to print
if printer then
    if printer.newPage() then
        printer.setPageTitle("Printed Text")
        printer.setCursorPos(1, 1)
        printer.write(text)
        
        if printer.endPage() then
            print("Success! Text printed.")
        else
            print("Error: Failed to complete printing")
        end
    else
        print("Error: Printer out of paper or ink")
    end
else
    print("Printer not found! Output to console:")
    print(text)
end