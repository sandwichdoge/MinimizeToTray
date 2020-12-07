
import xlrd

workbook = xlrd.open_workbook("language_gen.xlsx")
sheet = workbook.sheet_by_index(0)
data = [sheet.row_values(rowx) for rowx in range(sheet.nrows)]

def write_file(path, data):
    print('Writing to', path)
    h = open(path, 'w', encoding='utf-8')
    h.write(data)
    h.close()


# TODO: check to make sure all lines are equal


for index, i in enumerate(data):
    if data[index] == None:
        data[index] = list(filter(None, data[index]))

langtest = data[1][1:]
langtest = list(filter(None, langtest))
print('Total number of languages: ' + str(len(langtest)))
print(langtest)

data = data[1:]
col = 1
for language in langtest:
    if col > len(langtest):
        break
    final = ''
    for line in data:
        if not line:
            continue
        fields = line
        if not fields[0]:
            continue
        final += '\"' + fields[0] + '\"' #key
        final += ' : '
        final += '\"' + fields[col] + '\"'
        final += ',\n'

    col += 1

    final = '{\n' + final
    final = final[:-2]
    final += '\n}'

 
    write_file(language + '.json', final)
