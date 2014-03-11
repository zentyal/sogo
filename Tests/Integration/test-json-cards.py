#!/usr/bin/python

# This module test the exportation and importation of contacts from/to JSON

from config import hostname, port, username, password

import copy
import json
import sogotests
import unittest
import webdavlib


class JSONCardsTests(unittest.TestCase):
    def testJsonMethod(self):
        self.maxDiff = None
        deletes = []
        client = webdavlib.WebDAVClient(hostname, port)

        # json connect
        form_data = {"userName": username,
                     "password": password}
        data = json.dumps(form_data)

        post = webdavlib.HTTPPOST("/SOGo/so/connect", data,
                                  content_type = "application/json")
        client.execute(post)
        self.assertEquals(post.response["status"], 200)

        # retrieve auth cookie for further ops
        cookie = post.response["headers"]["set-cookie"]
        parts = cookie.split(";")
        login_value = parts[0].strip()
        card_uid = "json-contact-for-export"
        card_url = "/SOGo/so/%s/Contacts/personal/%s.vcf" % (username, card_uid)

        # delete old version of future card if exists
        post = webdavlib.HTTPPOST("%s/delete" % card_url, "")
        post.cookie = login_value
        client.execute(post)

        # first version of the card
        card_data = {
            "tag": "vcard",
            "properties": [
                {"tag": "uid", "values": [["json-contact-for-export.vcf"]]},
                {"tag": "version", "values": [["3.0"]]},
                {"tag": "class", "values": [["PUBLIC"]]},
                {"tag": "profile", "values":  [["VCARD"]]},
                {"tag": "n", "values":  [["Card"], ["Json"]]},
                {"tag": "fn", "values":  [["Json Card"]]},
                {"tag": "email", "values":  [["nouvelle@carte.com"]],
                 "parameters": {"type": ["work"]}}
            ]
        }

        # schedule the deletion of the future card
        deletes.append(webdavlib.RAIIOperation(client, post))

        # create it via POST on /json
        data = json.dumps(card_data)
        post = webdavlib.HTTPPOST("%s/json" % card_url, data,
                                  content_type = "application/json")
        post.cookie = login_value
        client.execute(post)
        self.assertEquals(post.response["status"], 201)
        self.assertEquals(post.response["body"], "")

        # fetch json content via /json method
        get = webdavlib.HTTPGET(card_url + "/json")
        get.cookie = login_value
        client.execute(get)
        self.assertEquals(get.response["status"], 200)
        self.assertEquals(card_data, json.loads(get.response["body"]))

        # update it via POST on /json
        card_data['properties'][5]['values'][0][0] = 'Imported card'
        data = json.dumps(card_data)
        post = webdavlib.HTTPPOST("%s/json" % card_url, data,
                                  content_type = "application/json")
        post.cookie = login_value
        client.execute(post)
        self.assertEquals(post.response["status"], 204)
        self.assertEquals(post.response["body"], "")

        # refetch the card and ensures the contents match the updated version
        get = webdavlib.HTTPGET(card_url + "/json")
        get.cookie = login_value
        client.execute(get)
        self.assertEquals(get.response["status"], 200)
        self.assertEquals(card_data, json.loads(get.response["body"]))


if __name__ == "__main__":
    sogotests.runTests()
