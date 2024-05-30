import 'dart:convert';
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:notlar/components/themenotifier.dart';
import 'package:notlar/models/note.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'folders/notecontentpage.dart';

class AllNotesPage extends StatefulWidget {
  final List<Note> notes;
  final List<Note> deletedNotes;
  final List<Note> archivedNotes;
  const AllNotesPage(
      {Key? key,
        required this.notes,
        required this.deletedNotes,
        required this.archivedNotes})
      : super(key: key);

  @override
  State<AllNotesPage> createState() => _AllNotesPageState();
}

class _AllNotesPageState extends State<AllNotesPage> {
  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return Center(
      child: widget.notes.isEmpty
          ? Text("Henüz hiç not kaydedilmemiş.")
          : ListView.builder(
        itemCount: widget.notes.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(widget.notes[index].noteTitle),
            onTap: () {
              // Nota basıldığında yapılacak işlemler buraya yazılabilir
              editNote(context, index);
            },
            onLongPress: () {
              // Aşağıdan açılır menüyü göster
              showModalBottomSheet(
                context: context,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20.0),
                  ),
                ),
                backgroundColor: Colors.transparent,
                builder: (context) {
                  return Container(
                    decoration: BoxDecoration(
                      color: themeNotifier.isDarkMode ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20.0),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('İçeriği Düzenle'),
                          onTap: () {
                            // Düzenleme işlemi
                            Navigator.pop(context);
                            editNote(context, index);
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.delete),
                          title: Text('Sil'),
                          onTap: () {
                            // Silme işlemi
                            Navigator.pop(context);
                            deleteNoteConfirmation(context, index);
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.archive),
                          title: Text('Arşivle'),
                          onTap: () {
                            // Arşivleme işlemi
                            Navigator.pop(context);
                            archiveNoteConfirmation(context, index);
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Başlığı Yeniden Adlandır'),
                          onTap: () {
                            // Yeniden adlandırma işlemi
                            Navigator.pop(context);
                            renameNote(context, index);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void editNote(BuildContext context, int index) {
    // Düzenleme işlemi öncesi not içeriği sayfasına yönlendir
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteContentPage(note: widget.notes[index]),
      ),
    ).then((editedNote) async {
      if (editedNote != null) {
        if (await updateWithAPI(editedNote)) {
          widget.notes[index] = editedNote;
          // Eğer not içeriği düzenlendiyse, düzenlenen notu güncelle
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Not Düzenlendi: ${widget.notes[index].noteTitle}'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void deleteNoteConfirmation(BuildContext context, int index) {
    // Silme işlemi için onay isteme
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Notu Sil"),
          content: Text("Bu notu silmek istiyor musun?"),
          actions: <Widget>[
            TextButton(
              child: Text("Evet"),
              onPressed: () {
                deleteNote(context, index);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Hayır"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void deleteNote(BuildContext context, int index) async {
    // Silme işlemi

    String oldFolder = widget.notes[index].folderName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.notes[index].noteTitle} Silindi'),
        duration: Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Geri Al',
          onPressed: () async {
            Note newNote = widget.deletedNotes.last;
            if (await updateFolderWithAPI(newNote, oldFolder)) {
              widget.deletedNotes.removeLast();
              widget.notes.add(newNote);
              setState(() {
                //widget.notes.insert(index, deletednotes.last);
                //deletednotes.removeLast();
              });
            }
          },
        ),
      ),
    );
    // Notu listeden kaldır
    if (await deleteWithAPI(widget.notes[index])) {
      widget.deletedNotes.add(widget.notes[index]);
      widget.notes.removeAt(index);
      setState(() {
        //arkaplanda işlem başarılıysa, gösterilen veriyi günceller
      });
    }
  }

  void archiveNoteConfirmation(BuildContext context, int index) {
    // Arşivleme işlemi için onay isteme
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Notu Arşivle"),
          content: Text("Bu notu arşivlemek istiyor musun?"),
          actions: <Widget>[
            TextButton(
              child: Text("Evet"),
              onPressed: () {
                archiveNote(context, index);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Hayır"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> archiveNote(BuildContext context, int index) async {
    // Arşivleme işlemi

    String oldFolder = widget.notes[index].folderName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.notes[index].noteTitle} Arşivlendi'),
        duration: Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Geri Al',
          onPressed: () async {
            // Arşivlenen notu geri ekle
            Note newNote = widget.deletedNotes.last;
            if (await updateFolderWithAPI(newNote, oldFolder)) {
              widget.archivedNotes.removeLast();
              widget.notes.add(newNote);
              setState(() {
                //widget.notes.insert(index, archivednotes.last);
                //archivednotes.removeLast();
              });
            }
          },
        ),
      ),
    );
    // Notu listeden kaldır ve arşivlere ekle
    if (await archiveWithAPI(widget.notes[index])) {
      widget.archivedNotes.add(widget.notes[index]);
      widget.notes.removeAt(index);
      setState(() {
        //arkaplanda işlem başarılıysa, gösterilen veriyi günceller
      });
    }
  }

  void renameNote(BuildContext context, int index) {
    // Yeniden adlandırma işlemi
    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController controller =
            TextEditingController(text: widget.notes[index].noteTitle);
        return AlertDialog(
          title: Text("Yeniden Adlandır"),
          content: TextFormField(
            autofocus: true, // Klavye otomatik olarak açılsın
            controller: controller,
            decoration: InputDecoration(hintText: "Yeni Not Adı"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("İptal"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Kaydet"),
              onPressed: () async {
                String newName = controller.text;
                // Yeni ismi kullanarak notu yeniden adlandır
                widget.notes[index].noteTitle = newName;
                if (await updateWithAPI(widget.notes[index])) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Not başlığı güncellendi: $newName'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  Navigator.of(context).pop();
                  setState(() {});
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Not başlığı güncellenemedi.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> deleteWithAPI(Note note) {
    return updateFolderWithAPI(note, "Çöp Kutusu");
  }

  Future<bool> archiveWithAPI(Note note) {
    return updateFolderWithAPI(note, "Arşiv");
  }

  Future<bool> updateWithAPI(Note note) async {
    String url = 'http://10.0.2.2:8080/api/notes/${note.id}';
    //10 sn time limit

    final response = await http.put(
      Uri.parse(url),
      body: json.encode(note),
      headers: {
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> updateFolderWithAPI(Note note, String folderName) {
    note.folderName = folderName;
    return updateWithAPI(note);
  }
}
