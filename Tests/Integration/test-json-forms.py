#!/usr/bin/python


from config import hostname, port, username, password

import json
import sogotests
import unittest
import webdavlib


class JSONFormsTests(unittest.TestCase):
    def testJsonContactCreationViaSo(self):
        self._doJsonContactCreation("so")

    def testJsonContactCreationViaJson(self):
        self._doJsonContactCreation("json")

    def _doJsonContactCreation(self, prefix):
        deletes = []

        client = webdavlib.WebDAVClient(hostname, port)

        # json connect
        form_data = {"userName": username,
                     "password": password}
        data = json.dumps(form_data)

        post = webdavlib.HTTPPOST("/SOGo/%s/connect" % prefix, data,
                                  content_type = "application/json")
        client.execute(post)
        self.assertEquals(post.response["status"], 200)

        # retrieve auth cookie for further ops
        cookie = post.response["headers"]["set-cookie"]
        parts = cookie.split(";")
        login_value = parts[0].strip()
        card_uid = "json-contact-%s" % prefix
        base_url = "/SOGo/%s/%s/Contacts/personal/%s.vcf" % (prefix, username, card_uid)

        # delete old version of future card if exists
        post = webdavlib.HTTPPOST("%s/delete" % base_url, "")
        post.cookie = login_value
        client.execute(post)

        # create card
        card_data = {"givenname": "Json",
                     "sn": "Card",
                     "displayname": "Json Card",
                     "mail": "nouvelle@carte.com"}
        data = json.dumps(card_data)
        deletes.append(webdavlib.RAIIOperation(client, post))
        post = webdavlib.HTTPPOST("%s/saveAsContact" % base_url,
                                  data, content_type = "application/json")
        post.cookie = login_value
        client.execute(post)
        self.assertEquals(post.response["status"], 200)

if __name__ == "__main__":
    sogotests.runTests()
